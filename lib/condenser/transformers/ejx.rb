class Condenser::EjxTransformer < Condenser::NodeProcessor

  def initialize(options = {})
    @options = options
  end
  
  def self.setup(environment)
    require 'ejx' unless defined?(::EJX)

    if !environment.path.include?(EJX::ASSET_DIR)
      environment.append_path(EJX::ASSET_DIR)
    end
  end
  
  def self.call(environment, input)
    new.call(environment, input)
  end

  def call(environment, input)
    input[:source] = EJX::Template.new(input[:source], @options).to_module
  end

end