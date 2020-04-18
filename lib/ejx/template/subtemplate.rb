class EJX::Template::Subtemplate

  attr_reader :children
  
  def initialize(opening, modifiers)
    @children = [opening]
    @modifiers = modifiers
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output")
    output_var = var_generator.next
    output =  "#{' '*indentation}var #{output_var} = [];\n"
    output << "#{' '*indentation}__ejx_append("
    output << @children.first
    output << "\n"

    # var_generator ||= EJX::Template::VarGenerator.new
    @children[1..-2].each do |child|
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{output_var}, false, __promises);\n"
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: output_var)
      end
    end
    output << ' '*indentation
    output << @children.last
    output << ", #{append}, true, __promises, #{output_var});\n"

    output
  end

end