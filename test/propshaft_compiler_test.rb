# frozen_string_literal: true

require "test_helper"

class FakeAsset
  attr_reader :logical_path
  def initialize(logical_path)
    @logical_path = Pathname.new(logical_path)
  end
end

class PropshaftCompilerTest < Minitest::Test
  def test_pass_through_for_js
    skip unless defined?(Propshaft)
    compiler = Propshaft::Compiler::Ejx.allocate
    asset = FakeAsset.new("components/app.js")
    input = "console.log('ok')"
    assert_equal input, compiler.send(:compile, asset, input)
  end

  def test_compiles_ejx
    skip unless defined?(Propshaft)
    compiler = Propshaft::Compiler::Ejx.allocate
    asset = FakeAsset.new("components/show.html.ejx")
    input = "Hello <%= 'world' %>"
    out = compiler.send(:compile, asset, input)
    assert_includes out, "export default async function self"
    assert_includes out, "Hello"
  end
end

