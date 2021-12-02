class EJX::Template::Multitemplate < EJX::Template::Subtemplate

  def to_js(indentation: 4, var_generator: nil, append: "__output")
    output = "#{' '*indentation}__ejx_append("
    output << @children.first << "\n"

    @children[1..-2].each do |child|
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{append}, false, __promises);\n"
      when String
        "#{' '*(indentation)}#{child}\n"
      when EJX::Template::Subtemplate
        child.to_sub_js(indentation: indentation + 4, var_generator: var_generator)
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: append)
      end
    end

    output << ' '*indentation << @children.last.strip.delete_suffix(';')
    output << ", #{append}, true, __promises);\n"

    output
  end

end