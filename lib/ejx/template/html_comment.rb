# frozen_string_literal: true

class EJX::Template::HTMLComment

  def initialize(comment)
    @comment = comment
  end

  def to_s
    @comment
  end

  def inspect
    "#<EJX::HTMLComment:#{self.object_id} @comment=#{@comment}>"
  end

  def to_js(append: "__output", var_generator:, indentation: 4, namespace: nil)
    "#{' '*indentation}#{append}.push(document.createComment(#{JSON.generate(@comment)}));\n"
  end
  
end