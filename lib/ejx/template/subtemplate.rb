class EJX::Template::Subtemplate

  attr_reader :children, :append
  
  def initialize(opening, modifiers, append: true)
    @children = [opening]
    @modifiers = modifiers
    @append = append
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output")
    output = ''
    already_assigned = @children.first =~ /\A\s*(var|const|let)\s+(\S+)/
    global_output_var = already_assigned ? $2 : var_generator.next
    output_var = var_generator.next

    if already_assigned# || !@append
      output << "#{' '*indentation}#{@children.first}\n"
    else
      output << "#{' '*indentation}var #{global_output_var} = [];\n"
      output << "#{' '*indentation}__ejx_append("
      output << @children.first << "\n"
    end

    output << "#{' '*(indentation+4)}var #{output_var} = [];\n"
    @children[1..-2].each do |child|
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{output_var}, false, __promises);\n"
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: output_var)
      end
    end

    if !already_assigned
      output << ' '*(indentation+4) << "#{global_output_var}.push(#{output_var});\n" if @append
    end
    output << ' '*(indentation+4) << "return #{output_var};\n";
    output << ' '*indentation << @children.last.strip.delete_suffix(';')
    
    output << if already_assigned
      if @append
        ";\n#{' '*indentation}__ejx_append(#{global_output_var}, #{append}, true, __promises);\n"
      else
        ";\n"
      end
    else
      if @append
        ", #{append}, true, __promises, #{global_output_var});\n"
      else
        ";\n"
      end
    end

    output
  end

end