class EJX::Template::JS
  
  attr_reader :value
  
  def initialize(value, modifiers = [])
    @modifiers = modifiers
    @value = value
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output", promises: '__promises')
    states = {}
    preamble = ""
    output = @value.gsub(/stateof[\(\s]\s*(\w+)/) do |var_name|
      state_name = var_generator.next
      states[state_name] = $1
      state_name
    end

    states.each do |var_name, bus_name|
      preamble << "var #{var_name} = state(#{bus_name});\n"
    end
    
        
    if @modifiers.include? :escape
      if output =~ /\A\s*(var|const|let)\s+(\S+)/
        "#{' '*indentation}#{preamble}" +
        "#{' '*indentation}#{output}#{output.strip.end_with?(';') ? '' : ';'}\n#{' '*indentation}__ejx_append(#{$2}, #{append}, 'escape', #{promises});\n"
      else
        "#{' '*indentation}#{preamble}" +
        "#{' '*indentation}__ejx_append(#{output.gsub(/;\s*\Z/, '')}, #{append}, 'escape', #{promises});\n"
      end
    elsif @modifiers.include? :unescape
      "#{' '*indentation}#{preamble}" +
      "#{' '*indentation}__ejx_append(#{output.gsub(/;\s*\Z/, '')}, #{append}, 'unescape', #{promises});\n"
    elsif @modifiers.include? :comment
      "#{' '*indentation}#{preamble}" +
      "#{' '*indentation}#{output.index("\n").nil? ? "// #{output}" : "/* #{output.gsub(/\n\s+/, "\n"+(' '*indentation)+"   ")} */"}\n"
    else
      "#{' '*indentation}#{preamble}" +
      "#{' '*indentation}#{output}\n"
    end
  end
end