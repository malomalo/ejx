class EJX::Template::JS
  
  attr_reader :value
  
  def initialize(value, modifiers = [])
    @modifiers = modifiers
    @value = value
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output")
    output = @value
    
    if @modifiers.include? :escape
      if output =~ /\A\s*(var|const|let)\s+(\S)/
        "#{' '*indentation}#{output}#{output.strip.end_with?(';') ? '' : ';'}\n#{' '*indentation}__ejx_append(#{$2}, #{append}, true, __promises);\n"
      else
        "#{' '*indentation}__ejx_append(#{output}, #{append}, true, __promises);\n"
      end
    elsif @modifiers.include? :unescape
      "#{' '*indentation}__ejx_append(#{output}, #{append}, false, __promises);\n"
    elsif !@modifiers.include? :comment
      "#{' '*indentation}#{output}\n"
    else
      "#{' '*indentation}//#{output}\n"
    end
  end
end