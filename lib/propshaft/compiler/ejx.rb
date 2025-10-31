# frozen_string_literal: true

begin
  require "propshaft"
rescue LoadError
  # Propshaft optional
end

class Propshaft::Compiler::Ejx < ::Propshaft::Compiler
  # Compile only EJX/EJS sources; pass-through regular JS
  def compile(asset, input)
    require "ejx" unless defined?(::EJX)

    logical = asset.logical_path.to_s
    if logical.match(/\.(?:ejx|ejs)(?:\.html)?\z/) || logical.match(/\.html\.(?:ejx|ejs)\z/)
      ::EJX.compile(input)
    else
      input
    end
  end
end

## Registration is handled from the Railtie to ensure proper load order.
