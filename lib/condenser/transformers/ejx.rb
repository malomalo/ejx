class Condenser::EjxTransformer < Condenser::NodeProcessor

  attr_writer :options
  
  def initialize(options = {})
    super()
    @options = options
  end

  def options
    require 'ejx' unless defined?(::EJX)

    @options.merge(
      open_tag: @options[:open_tag] || EJX.settings[:open_tag],
      close_tag: @options[:close_tag] || EJX.settings[:close_tag],
      open_tag_modifiers: EJX.settings[:open_tag_modifiers].merge(@options[:open_tag_modifiers] || {}),
      close_tag_modifiers: EJX.settings[:close_tag_modifiers].merge(@options[:close_tag_modifiers] || {})
    )
  end
  
  def setup(environment)
    require 'ejx' unless defined?(::EJX)

    if !environment.path.include?(EJX::ASSET_DIR)
      environment.append_path(EJX::ASSET_DIR)
    end
  end

  def call(environment, input)
    input[:source] = EJX::Template.new(input[:source], @options.merge(filename: input[:filename])).to_module
  end

end
