class EJX::Template::HTMLTag::AttributeValue

  def initialize(values)
    @values = values
  end

  def to_js
    if @values.empty?
      JSON.generate('')
    else
      "[" + @values.map{ |v| v.is_a?(::String) ? JSON.generate(v) : v.value }.join(', ') + "].join(\"\")"
    end
  end
  
end