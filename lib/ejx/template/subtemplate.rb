class EJX::Template::Subtemplate

  attr_reader :children, :modifiers
  
  [:assigned_to_variable, :async, :append].each do |fn_name|
    attr_reader fn_name
    define_method(:"#{fn_name}?", instance_method(fn_name))
  end
  
  def function?
    !!@function_type
  end
  
  def arrow_function?
    @function_type == :arrow
  end
  
  def initialize(opening, modifiers, append: true)
    @children = [opening]
    @modifiers = modifiers
    @append = append
    
    @assigned_to_variable = @children.first&.match(/\A\s*(var|const|let)\s+(\S+)/)&.send(:[], 2)
    @async = false
    
    if match = @children.first&.match(/(?:async\s+)?function\s*\([^\)]*\)\s*\{\s*\Z/m)
      @function_type = :regular
      @async = match[0].start_with?('async')
    elsif match = @children.first&.match(/(?:async)?(?:\s*\([^\)\(]*\)|(?:(?<=\()|\s+)[^\(\s]+)?\s*=>\s*\{\s*\Z/m)
      @function_type = :arrow
      @async = match[0].start_with?('async')
    end
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output", promises: '__promises')
    output = ''

    global_output_var = var_generator.next if !assigned_to_variable?
    sub_global_output_var = var_generator.next
    output_var = var_generator.next

    if assigned_to_variable?
      output << "#{' '*indentation}#{@children.first}\n"
      output << "#{' '*(indentation+4)}var #{sub_global_output_var}_promises = [];\n"
    elsif !(@modifiers & [:escape, :unescape]).empty?
      output << "#{' '*indentation}var #{global_output_var}_result = #{@children.first}\n"
      output << "#{' '*(indentation+4)}var #{sub_global_output_var}_promises = [];\n"
    else
      output << <<~JS.gsub(/\n+\Z/, '')
        #{' '*(indentation)}var #{global_output_var}_results = [];
        #{' '*(indentation)}var #{global_output_var}_promises = [];
        #{' '*(indentation)}var #{global_output_var}_result = 
      JS
      
      indentation += 4
      output << if arrow_function?
        @children.first.sub(/((?:async)?(?:\s*\([^\)\(]*\)|(?:(?<=\()|\s+)[^\(\s]+)?\s*=>\s*\{\s*)\Z/m, <<~JS)
          (...__args) => {
          #{' '*(indentation)}var #{sub_global_output_var}_results = [];
          #{' '*(indentation)}var #{sub_global_output_var}_promises = [];
          #{' '*(indentation)}var #{sub_global_output_var}_result = (\\1
        JS
      else
        @children.first.sub(/((?:async\s+)?\s*function\s*\([^\)\(]*\)\s*\{\s*)\Z/m, <<~JS)
          (...__args) => {
          #{' '*(indentation)}var #{sub_global_output_var}_results = [];
          #{' '*(indentation)}var #{sub_global_output_var}_promises = [];
          #{' '*(indentation)}var #{sub_global_output_var}_result = (\\1
        JS
      end
    end

    output << "#{' '*(indentation+4)}var #{output_var} = [];\n"
    
    @children[1..-2].each do |child|
      promise_var = "#{sub_global_output_var}_promises"
      output << case child
      when EJX::Template::String
        "#{' '*(indentation+4)}__ejx_append(#{child.to_js}, #{output_var}, 'unescape', #{promise_var});\n"
      else
        child.to_js(indentation: indentation + 4, var_generator: var_generator, append: output_var, promises: promise_var)
      end
    end

    if !assigned_to_variable? && (@modifiers & [:escape, :unescape]).empty?
      output << ' '*(indentation+4) << "#{sub_global_output_var}_results.push(#{output_var});\n"
    end

    if async?
      output << ' '*(indentation+4) << "await Promise.all(#{sub_global_output_var}_promises);\n"
      output << ' '*(indentation+4) << "return #{output_var};\n";
    elsif assigned_to_variable?
      output << ' '*(indentation+4)
      output << "return #{sub_global_output_var}_promises.length === 0 ? #{output_var} : Promise.all(#{sub_global_output_var}_promises).then(() => #{output_var});\n"
    else
      output << ' '*(indentation+4) << "return Promise.all(#{sub_global_output_var}_promises).then(() => #{output_var});\n"
    end

    output << ' '*((@modifiers & [:escape, :unescape]).empty? ? indentation : indentation-4)

    split = @children.last.strip.delete_suffix(';').split(/\}/, 2)
    output << split[0]
      
    if !assigned_to_variable? && (@modifiers & [:escape, :unescape]).empty?
      output << "})(...__args);\n"
      output << "#{' '*indentation}__ejx_append(#{sub_global_output_var}_results, #{global_output_var}_results, 'escape', #{global_output_var}_promises, #{sub_global_output_var}_result);\n"
      output << ' '*(indentation) << "return #{sub_global_output_var}_result;\n"
      output << ' '*(indentation-4) << "}" << split[1]
    else
      output << ' '*(indentation-4) << "}" << split[1]
    end
    indentation = indentation - 4
    
    if assigned_to_variable?
      output << ";\n"
      if !(@modifiers & [:escape, :unescape]).empty?
        output << "#{' '*indentation}__ejx_append(#{@assigned_to_variable}, #{append}, 'escape', #{promises});\n"
      end
    else
      output << ";\n"
      if !(@modifiers & [:escape, :unescape]).empty?
        output << "#{' '*(indentation+4)}__ejx_append(#{global_output_var}_result, #{append}, 'escape', #{promises});\n"
      else
        output << "#{' '*indentation}__ejx_append(#{global_output_var}_results.flat(1), #{append}, 'escape', #{promises}, "
        output << "(#{global_output_var}_result instanceof Promise) ? #{global_output_var}_result.then(() => Promise.all(#{global_output_var}_promises).then(r => r.flat(1))) : Promise.all(#{global_output_var}_promises).then(r => r.flat(1)));\n"
      end
    end

    output
  end
  
  def to_sub_js(indentation: 4, var_generator: nil, promises: '__promises')
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