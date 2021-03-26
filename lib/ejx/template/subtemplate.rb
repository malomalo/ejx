class EJX::Template::Subtemplate

  attr_reader :children
  
  def initialize(opening, modifiers)
    @children = [opening]
    @modifiers = modifiers
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output")
    global_output_var = var_generator.next
    output_var = var_generator.next
    
    output =  "#{' '*indentation}var #{global_output_var} = [];\n"
    output << "#{' '*indentation}__ejx_append("
    output << @children.first << "\n"
    output << "#{' '*(indentation+4)}var #{output_var} = [];\n"
    
    @children[1..-2].each do |child|
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{output_var}, false, __promises);\n"
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: output_var)
      end
    end
    
    output << ' '*(indentation+4) << "#{global_output_var}.push(#{output_var});\n";
    output << ' '*(indentation+4) << "return #{output_var};\n";
    output << ' '*indentation << @children.last.strip.delete_suffix(';')
    output << ", #{append}, true, __promises, #{global_output_var});\n"

    output
  end

end