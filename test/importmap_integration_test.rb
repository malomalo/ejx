# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ImportmapIntegrationTest < Minitest::Test
  Mapping = Struct.new(:dir, :path, :under, :preload, :integrity, keyword_init: true)

  class DummyMap
    def initialize
    end

    # Methods our extension expects to exist on Importmap::Map
    def module_path_from(filename, mapping)
      [ mapping.path || mapping.under, filename.to_s ].compact.reject(&:empty?).join("/")
    end

    def find_javascript_files_in_tree(path)
      Dir[path.join("**/*.js{,m}")].sort.collect { |file| Pathname.new(file) }.select(&:file?)
    end
  end

  def with_temp_tree
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      FileUtils.mkdir_p(root.join("components"))
      %w[
        components/a.js
        components/b.mjs
        components/show.html.ejs
        components/card.ejs.html
        components/panel.ejx
        components/header.html.ejx
        components/ignore.txt
      ].each do |rel|
        path = root.join(rel)
        FileUtils.mkdir_p(path.dirname)
        File.write(path, "// stub")
      end

      yield root
    end
  end

  def test_extension_discovers_ejx_ejs_files
    require_relative "../lib/ejx/importmap_map_extensions"
    map = DummyMap.new
    map.extend(EJX::ImportmapMapExtensions)

    with_temp_tree do |root|
      files = map.find_javascript_files_in_tree(root).map { |p| p.relative_path_from(root).to_s }.sort

      assert_includes files, "components/a.js"
      # Note: importmap-rails scans "**/*.js{,m}" which matches .js and .jsm (not .mjs)
      assert_includes files, "components/show.html.ejs"
      assert_includes files, "components/card.ejs.html"
      assert_includes files, "components/panel.ejx"
      assert_includes files, "components/header.html.ejx"
      refute_includes files, "components/ignore.txt"
      # Ensure no duplicates from overlapping patterns
      assert_equal files.uniq, files
    end
  end

  def test_extension_keeps_original_paths_for_modules
    require_relative "../lib/ejx/importmap_map_extensions"
    map = DummyMap.new
    # We do not override module_path_from; default behavior should remain
    mapping = Mapping.new(under: "application")

    assert_equal "application/components/show.html.ejs",   map.module_path_from(Pathname.new("components/show.html.ejs"), mapping)
    assert_equal "application/components/card.ejs.html",   map.module_path_from(Pathname.new("components/card.ejs.html"), mapping)
    assert_equal "application/components/panel.ejx",       map.module_path_from(Pathname.new("components/panel.ejx"), mapping)
    assert_equal "application/components/header.html.ejx", map.module_path_from(Pathname.new("components/header.html.ejx"), mapping)
  end
end
