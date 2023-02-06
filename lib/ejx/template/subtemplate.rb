class EJX::Template::Subtemplate

  attr_reader :children, :append, :modifiers
  
  def initialize(opening, modifiers, append: true)
    @children = [opening]
    @modifiers = modifiers
    @append = append
    
    @function = @children.first =~ /(?:async\s+)?function\s*\([^\)]*\)\s*\{\s*\Z/m
    @arrow_function = @children.first =~ /(?:async)?(?:\s*\([^\)\(]*\)|(?:(?<=\()|\s+)[^\(\s]+)?\s*=>\s*\{\s*\Z/m
    @iterator = @function || @arrow_function
  end

  def has_nested_promises?
    @iterator || @children.any? { |c| c.is_a?(EJX::Template::Subtemplate) && c.has_nested_promises? }
  end
  
  def appending?
    @modifiers.any?
  end
  
  def to_js(indentation: 4, var_generator: nil, append: "__output", promises: '__promises')
    output = ''

    already_assigned = @children.first =~ /\A\s*(var|const|let)\s+(\S+)/
    global_output_var = already_assigned ? $2 : var_generator.next
    sub_global_output_var = if @iterator
       var_generator.next
    end
    output_var = var_generator.next

    if already_assigned
      output << "#{' '*indentation}#{@children.first}\n"
    elsif appending? && !@iterator
      output << "#{' '*(indentation)}var #{global_output_var}_results = [];\n"
      output << "#{' '*(indentation)}var #{global_output_var}_promises = [];\n"
      output << "#{' '*indentation}__ejx_append("
      output << @children.first << "\n"
    elsif @iterator
      output << "#{' '*(indentation)}var #{global_output_var}_results = [];\n"
      output << "#{' '*(indentation)}var #{global_output_var}_promises = [];\n"
      output << "#{' '*indentation}__ejx_append("
      indentation += 4
      output << if @function
        @children.first.sub(/((?:async\s+)?\s*function\s*\([^\)\(]*\)\s*\{\s*)\Z/m, "(...__args) => {\n#{' '*indentation}var #{sub_global_output_var}_results = [];\n#{' '*indentation}var #{sub_global_output_var}_promises = [];\n#{' '*indentation}return __ejx_append((\\1\n")
      else
        @children.first.sub(/((?:async)?(?:\s*\([^\)\(]*\)|(?:(?<=\()|\s+)[^\(\s]+)?\s*=>\s*\{\s*)\Z/m, "(...__args) => {\n#{' '*indentation}var #{sub_global_output_var}_results = [];\n#{' '*indentation}var #{sub_global_output_var}_promises = [];\n#{' '*indentation}return __ejx_append((\\1\n")
      end
    else
      puts '!!!'
    end

    output << "#{' '*(indentation+4)}var #{output_var} = [];\n"
    
    @children[1..-2].each do |child|
      promise_var = @iterator ? "#{sub_global_output_var}_promises" : promises
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{output_var}, 'unescape', #{promise_var});\n"
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: output_var, promises: promise_var)
      end
    end

    if !already_assigned
      if @iterator
        output << ' '*(indentation+4) << "#{sub_global_output_var}_results.push(#{@iterator ? output_var : output_var});\n" if @append
      else
        output << ' '*(indentation+4) << "#{global_output_var}.push(#{@iterator ? output_var : output_var});\n" if @append
      end
    end

    output << ' '*(indentation+4) << "return #{output_var};\n";

    output << ' '*indentation
    if @iterator
      split = @children.last.strip.delete_suffix(';').split(/\}/, 2)
      output << split[0] << "})(...__args), #{global_output_var}_results, 'escape', #{global_output_var}_promises, #{sub_global_output_var}_results, #{sub_global_output_var}_promises);\n"
      output << ''
      indentation = indentation - 4
      output << ' '*indentation << "}" << split[1]
    else
      output << @children.last.strip.delete_suffix(';')
    end
    
    output << if already_assigned
      if @append
        ";\n#{' '*indentation}__ejx_append(#{global_output_var}, #{append}, 'escape', #{promises});\n"
      else
        ";\n"
      end
    else
      if @append
        puts !@modifiers.empty?
        ", #{append}, #{already_assigned && @modifiers.empty? ? false : '"escape"'}, #{promises}, #{global_output_var}_results, #{global_output_var}_promises);\n"
      else
        ";\n"
      end
    end

    output
  end
  
  def to_sub_js(indentation: 4, var_generator: nil)
    output_var = var_generator.next
    
    output = "#{' '*(indentation)}var #{output_var} = [];\n"

    @children[1..-1].each do |child|
      output << case child
      when EJX::Template::String
        "#{' '*(indentation)}__ejx_append(#{child.to_js}, #{output_var}, 'unescape', #{promises});\n"
      else
        child.to_js(indentation: indentation, var_generator: var_generator, append: output_var)
      end
    end
    output << ' '*(indentation) << "return #{output_var};\n";

    output
  end

end