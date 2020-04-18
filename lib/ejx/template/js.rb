class EJX::Template::JS
  
  def initialize(value, modifiers)
    @modifiers = modifiers
    @value = value
  end

  def to_js(indentation: 4, var_generator: nil, append: "__output")
    output = @value
    
    if @modifiers.include? :escape
      "#{' '*indentation}__ejx_append(#{output}, #{append}, true, __promises);\n"
    elsif @modifiers.include? :unescape
      "#{' '*indentation}__ejx_append(#{output}, #{append}, false, __promises);\n"
    elsif !@modifiers.include? :comment
      "#{' '*indentation}#{output}\n"
    end
  end
end