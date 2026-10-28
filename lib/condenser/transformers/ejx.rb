class Condenser::EjxTransformer < Condenser::NodeProcessor

  attr_accessor :options
  
  def initialize(options = {})
    super()
    @options = options
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
