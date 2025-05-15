# frozen_string_literal: true

require 'json'

class EJX::Template::String

  def initialize(value)
    @value = value
  end

  def to_js
    JSON.generate(@value)
  end

end