module EJX

  class TemplateError < StandardError
  end
    
  autoload :Template, File.expand_path('../ejx/template', __FILE__)

  @@settings = {
    open_tag: '<%',
    close_tag: '%>',
    
    open_tag_modifiers: {
      escape: '=',
      unescape: '-',
      comment: '#',
      literal: '%'
    },
  
    close_tag_modifiers: {
      trim: '-',
      literal: '%'
    },
    
    escape: nil
  }
  
  ASSET_DIR = File.join(__dir__, 'ejx', 'assets')
  
  VOID_ELEMENTS = [
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr'
  ]

  def self.compile(source, options = {})
    EJX::Template.new(source, options).to_module
  end
  
  def self.settings
    @@settings
  end
  
  def self.settings=(value)
    @@settings = value
  end
end


if defined?(Condenser)
  Condenser.configure do
    autoload :EjxTransformer, 'condenser/transformers/ejx'
    register_mime_type 'application/ejx', extensions: '.ejx', charset: :unicode
    register_template  'application/ejx', Condenser::EjxTransformer
  end
end