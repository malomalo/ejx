# frozen_string_literal: true

class EJX::Template::Base < EJX::Template::Node
  
  attr_accessor :imports, :free_identifiers
  
  def initialize(**options)
    super
    @imports = []
  end
  
  def to_module
    var_generator = EJX::Template::VarGenerator.new
    
    header = if @escape
      "import {" + @escape.split('.').reverse.join(" as __ejx_append} from '") + "';\n"
    else
      String.new("import {append as __ejx_append} from 'ejx';\n")
    end
    
    @imports.each do |import|
      header << import << "\n"
    end

    free_ids = Array(@free_identifiers)

    output = header
    if free_ids && free_ids.any?
      output << "\nexport default async function self ({ #{free_ids.sort.join(', ')} } = {}) {\n"
    else
      output << "\nexport default async function self (locals) {\n"
    end
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
