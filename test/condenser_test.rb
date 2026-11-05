require 'test_helper'
require 'open3'
require 'tmpdir'
require 'fileutils'

class CondenserTest < Minitest::Test

  NPM_DIR = File.expand_path('../../tmp', __FILE__)

  # Records the templates it compiles
  class RecordingTransformer < Condenser::EjxTransformer
    attr_reader :calls

    def initialize(*)
      super
      @calls = []
    end

    def call(environment, input)
      @calls << input[:filename]
      super
    end
  end

  def setup
    @path = File.realpath(Dir.mktmpdir)
    FileUtils.mkdir_p(NPM_DIR)
    # So npm installs into NPM_DIR instead of the closest package.json
    File.write(File.join(NPM_DIR, 'package.json'), '{}') if !File.exist?(File.join(NPM_DIR, 'package.json'))
  end

  def teardown
    EJX.settings = @settings if @settings
    Condenser::NodeWorker.stop_workers
    FileUtils.remove_entry(@path, true)
  end

  def new_env(cache: Condenser::Cache::MemoryStore.new)
    env = Condenser.new(@path, logger: Logger.new('/dev/null'), npm_path: NPM_DIR, base: @path, cache: cache, listen: false, pipeline: false)
    env.register_preprocessor('application/javascript', Condenser::JSAnalyzer.new)
    env
  end

  def file(name, source)
    File.write(File.join(@path, name), source)
  end

  test "requiring ejx after condenser" do
    lib = File.expand_path('../../lib', __FILE__)
    output, status = Open3.capture2e(RbConfig.ruby, '-I', lib, '-e', <<~RUBY)
      require 'condenser'
      require 'ejx'
      print Condenser.templates['application/ejx'].class
    RUBY

    assert status.success?, output
    assert_equal 'Condenser::EjxTransformer', output
  end

  test "registers an EjxTransformer instance with the default options" do
    template = Condenser.templates['application/ejx']

    assert_instance_of Condenser::EjxTransformer, template
    assert_kind_of Condenser::Processor, template
    assert_equal({
      open_tag: '<%',
      close_tag: '%>',
      open_tag_modifiers: { escape: '=', unescape: '-', comment: '#', literal: '%' },
      close_tag_modifiers: { trim: '-', literal: '%' },
      escape: nil
    }, template.options)
  end

  test "a nil instance option falls back to EJX.settings" do
    @settings = EJX.settings
    transformer = Condenser::EjxTransformer.new(open_tag: nil, open_tag_modifiers: { comment: nil })
    EJX.settings = @settings.merge(open_tag: '{{')

    assert_equal '{{', transformer.options[:open_tag]
    assert_equal '#', transformer.options[:open_tag_modifiers][:comment]
  end

  test "options include the global EJX.settings" do
    @settings = EJX.settings
    transformer = Condenser::EjxTransformer.new
    before = transformer.options

    EJX.settings = @settings.merge(open_tag: '{{', close_tag: '}}')

    refute_equal before, transformer.options
    assert_equal '{{', transformer.options[:open_tag]
    assert_equal '}}', transformer.options[:close_tag]
  end

  test "instance options override the global EJX.settings" do
    @settings = EJX.settings
    EJX.settings = @settings.merge(
      open_tag: '{{',
      open_tag_modifiers: @settings[:open_tag_modifiers].merge(escape: '~')
    )
    transformer = Condenser::EjxTransformer.new(open_tag: '[[', open_tag_modifiers: { comment: '!' }, escape: 'escape.js')

    assert_equal '[[', transformer.options[:open_tag]
    assert_equal '%>', transformer.options[:close_tag]
    assert_equal({ escape: '~', unescape: '-', comment: '!', literal: '%' }, transformer.options[:open_tag_modifiers])
    assert_equal 'escape.js', transformer.options[:escape]
  end

  test "changing EJX.settings changes the cache key and etag" do
    @settings = EJX.settings
    file 'template.js.ejx', '<div>{{= x }}</div>'
    cache = Condenser::Cache::MemoryStore.new

    asset = new_env(cache: cache).find('template.js')
    cache_key, etag, source = asset.cache_key, asset.etag, asset.source

    EJX.settings = @settings.merge(open_tag: '{{', close_tag: '}}')
    asset = new_env(cache: cache).find('template.js')

    refute_equal cache_key, asset.cache_key
    refute_equal etag, asset.etag
    refute_equal source, asset.source
    assert_equal EJX.compile('<div>{{= x }}</div>'), asset.source
  end

  test "compiling a .js.ejx asset" do
    file 'template.js.ejx', '<div><%= x %></div>'
    env = new_env

    asset = env.find('template.js')
    asset.process

    assert_includes env.path, EJX::ASSET_DIR
    assert_equal ['application/javascript'], asset.content_types
    assert_equal EJX.compile('<div><%= x %></div>'), asset.source
    assert_equal [File.join(EJX::ASSET_DIR, 'ejx.js')], asset.export_dependencies.map(&:source_file)
  end

  test "compiling a .jst.ejx asset" do
    if !File.exist?(File.join(NPM_DIR, 'node_modules', '@babel', 'core'))
      # Condenser's JstTransformer doesn't support Babel 8 yet
      assert system('npm', 'install', '--silent', '--prefix', NPM_DIR, '@babel/core@7', '@babel/preset-env@7')
    end
    file 'template.jst.ejx', '<div><%= x %></div>'
    env = new_env

    asset = env.find('template.js')
    asset.process

    assert_includes env.path, EJX::ASSET_DIR
    assert_equal ['application/javascript'], asset.content_types
    assert_includes asset.source, "from 'ejx'"
    assert_includes asset.source, 'document.createElement("div")'
  end

  test "setup adds the asset directory for an app-registered instance with custom options" do
    file 'template.js.ejx', '<div>[[= x ]]</div>'
    transformer = Condenser::EjxTransformer.new(open_tag: '[[', close_tag: ']]')
    env = new_env
    env.register_template('application/ejx', transformer)
    refute_includes env.path, EJX::ASSET_DIR

    asset = env.find('template.js')
    asset.process

    assert_equal '[[', transformer.options[:open_tag]
    assert_equal ']]', transformer.options[:close_tag]
    assert_includes env.path, EJX::ASSET_DIR
    assert_equal EJX.compile('<div>[[= x ]]</div>', open_tag: '[[', close_tag: ']]'), asset.source
    assert_equal [File.join(EJX::ASSET_DIR, 'ejx.js')], asset.export_dependencies.map(&:source_file)
  end

  test "a warm build resolves the cached imports from the asset directory" do
    file 'template.js.ejx', '<div><%= x %></div>'
    cache = Condenser::Cache::MemoryStore.new

    cold = RecordingTransformer.new
    env = new_env(cache: cache)
    env.register_template('application/ejx', cold)
    env.find('template.js').export_dependencies
    assert_equal ['template.js'], cold.calls

    warm = RecordingTransformer.new
    env = new_env(cache: cache)
    env.register_template('application/ejx', warm)
    refute_includes env.path, EJX::ASSET_DIR

    dependencies = env.find('template.js').export_dependencies

    assert_empty warm.calls
    assert_includes env.path, EJX::ASSET_DIR
    assert_equal [File.join(EJX::ASSET_DIR, 'ejx.js')], dependencies.map(&:source_file)
  end

end
