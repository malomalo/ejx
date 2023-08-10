class EJX::Template::Node

  attr_accessor :children

  def initialize(escape: nil)
    @children = []
    @escape = escape
  end

  def push(*values)
    @children.push(*values)
    self
  end

  alias_method :<<, :push

end