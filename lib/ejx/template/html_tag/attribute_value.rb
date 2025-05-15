# frozen_string_literal: true

class EJX::Template::HTMLTag::AttributeValue

  def initialize(values)
    @values = values
  end

  def to_js
    if @values.empty?
      JSON.generate('')
    else
      @values.map do |value|
        if value.is_a?(::String)
          JSON.generate(value)
        elsif value.value =~ /\A\s*\w+\s*\z/
          value.value
        else
          "(" + value.value + ")"
        end
      end.join(' + ')
    end
  end
  
end