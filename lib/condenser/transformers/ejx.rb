class Condenser::EjxTransformer < Condenser::NodeProcessor

  attr_writer :options
  
  def initialize(options = {})
    super()
    @options = options
  end

  def options
    require 'ejx' unless defined?(::EJX)
    deep_merge(EJX.settings, @options)
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

  private

  def deep_merge(settings, options)
    settings.merge(options) do |_, setting, option|
      if option.nil?
        setting
      elsif setting.is_a?(Hash) && option.is_a?(Hash)
        deep_merge(setting, option)
      else
        option
      end
    end
  end

end
