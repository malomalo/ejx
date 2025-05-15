# frozen_string_literal: true

class EJX::Template::VarGenerator
  def initialize
    @current = nil
  end
  
  def next
    @current = @current.nil? ? '__a' : @current.next
    @current
  end
end