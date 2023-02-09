class EJX::Template::Subtemplate

  attr_reader :children, :append, :modifiers
  
  def initialize(opening, modifiers, append: true)
    @children = [opening]
    @modifiers = modifiers
    @append = append
    
    @function = false
    @arrow_function = false
    @async = false
    
    if match = @children.first.match(/(?:async\s+)?function\s*\([^\)]*\)\s*\{\s*\Z/m)
      @function = true
      @async = match[0].start_with?('async')
    elsif match = @children.first.match(/(?:async)?(?:\s*\([^\)\(]*\)|(?:(?<=\()|\s+)[^\(\s]+)?\s*=>\s*\{\s*\Z/m)
      @arrow_function = true
      @async = match[0].start_with?('async')
    end
    @iterator = @function || @arrow_function
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output", promises: '__promises')
    output = ''

    already_assigned = @children.first =~ /\A\s*(var|const|let)\s+(\S+)/
    global_output_var = already_assigned ? $2 : var_generator.next
    sub_global_output_var = var_generator.next
    output_var = var_generator.next

    if already_assigned
      output << "#{' '*indentation}#{@children.first}\n"
    elsif @iterator
      output << <<~JS.gsub(/\n+\Z/, '')
        #{' '*(indentation)}var #{global_output_var}_results = [];
        #{' '*(indentation)}var #{global_output_var}_promises = [];
        #{' '*(indentation)}var #{global_output_var}_result = 
      JS
      
      indentation += 4
      output << if @function
        @children.first.sub(/((?:async\s+)?\s*function\s*\([^\)\(]*\)\s*\{\s*)\Z/m, <<~JS)
          (...__args) => {
          #{' '*(indentation)}var #{sub_global_output_var}_results = [];
          #{' '*(indentation)}var #{sub_global_output_var}_promises = [];
          #{' '*(indentation)}var #{sub_global_output_var}_result = (\\1
        JS
      else
        @children.first.sub(/((?:async)?(?:\s*\([^\)\(]*\)|(?:(?<=\()|\s+)[^\(\s]+)?\s*=>\s*\{\s*)\Z/m, <<~JS)
          (...__args) => {
          #{' '*(indentation)}var #{sub_global_output_var}_results = [];
          #{' '*(indentation)}var #{sub_global_output_var}_promises = [];
          #{' '*(indentation)}var #{sub_global_output_var}_result = (\\1
        JS
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


    if @iterator
      output << ' '*(indentation+4) << "#{sub_global_output_var}_results.push(#{@iterator ? output_var : output_var});\n"
      if @async
        output << ' '*(indentation+4) << "await Promise.all(#{sub_global_output_var}_promises);\n"
        output << ' '*(indentation+4) << "return #{output_var};\n";
      else
        output << ' '*(indentation+4) << "return Promise.all(#{sub_global_output_var}_promises).then(() => #{output_var});\n"
      end
    else
      output << ' '*(indentation+4) << "#{global_output_var}.push(#{@iterator ? output_var : output_var});\n" if @append
      output << ' '*(indentation+4) << "return #{output_var};\n";
    end

    output << ' '*indentation
    if @iterator
      split = @children.last.strip.delete_suffix(';').split(/\}/, 2)
      output << split[0] << "})(...__args);\n"
      output << ' '*(indentation) << "return __ejx_append(#{sub_global_output_var}_results, #{global_output_var}_results, 'escape', #{global_output_var}_promises, #{sub_global_output_var}_result);\n"
      output << ''
      indentation = indentation - 4
      output << ' '*indentation << "}" << split[1]
    else
      output << @children.last.strip.delete_suffix(';')
    end
    
    if already_assigned
      output << if @append
        ";\n#{' '*indentation}__ejx_append(#{global_output_var}, #{append}, 'escape', #{promises});\n"
      else
        ";\n"
      end
    else
      output << ";\n"
      if @append
        output << "#{' '*indentation}__ejx_append(#{global_output_var}_results.flat(1), #{append}, 'escape', #{promises}, "
        output << "(#{global_output_var}_result instanceof Promise) ? #{global_output_var}_result.then(() => Promise.all(#{global_output_var}_promises).then(r => r.flat(1))) : Promise.all(#{global_output_var}_promises).then(r => r.flat(1)));\n"
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