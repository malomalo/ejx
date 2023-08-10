class EJX::Template::Base < EJX::Template::Node
  
  attr_accessor :imports
  
  def initialize(**options)
    super
    @imports = []
  end
  
  def to_module
    var_generator = EJX::Template::VarGenerator.new
    
    output = if @escape
      "import {" + @escape.split('.').reverse.join(" as __ejx_append} from '") + "';\n"
    else
      "import {append as __ejx_append} from 'ejx';\n"
    end
    
    @imports.each do |import|
      output << import << "\n"
    end
    
    output << "\nexport default async function (locals) {\n"
    output << "    var __output = [], __promises = [];\n    \n"
    
    @children.each do |child|
      output << case child
      when EJX::Template::String
        "    __output.push(#{child.to_js});\n"
      else
        child.to_js(var_generator: var_generator)
      end
    end
    
    output << "\n    await Promise.all(__promises);"

    output << "\n    return __output;"
    output << "\n}"

    output
  end

end