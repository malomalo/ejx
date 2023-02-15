class EJX::Template::Multitemplate < EJX::Template::Subtemplate

  def to_js(indentation: 4, var_generator: nil, append: "__output", promises: '__promises')
    already_assigned = @children.first =~ /\A\s*(var|const|let)\s+(\S+)/
    output_var = $2
    output = ""
    if already_assigned# || !@append
      output << "#{' '*indentation}#{@children.first}\n"
    else
      output << "#{' '*indentation}__ejx_append("
      output << @children.first << "\n"
    end
    
    @children[1..-2].each do |child|
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{append}, 'unescape', __promises);\n"
      when String
        "#{' '*(indentation)}#{child}\n"
      when EJX::Template::Subtemplate
        child.to_sub_js(indentation: indentation + 4, var_generator: var_generator, promises: promises)
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: append)
      end
    end
    
    output << ' '*indentation << @children.last.strip.delete_suffix(';')
    if already_assigned
      output << ";\n#{' '*indentation}__ejx_append(#{output_var}, #{append}, 'escape', __promises);\n"
    else
      output << ", #{append}, true, __promises);\n"
    end

    output
  end

end