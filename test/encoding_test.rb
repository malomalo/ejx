require 'test_helper'

class EncodingTest < Minitest::Test

  module CaptureWarnings
    def warn(message, **)
      if (captured = Thread.current[:ejx_warnings])
        captured << message
      else
        super
      end
    end
  end
  Warning.singleton_class.prepend(CaptureWarnings)

  def capture_warnings
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    Thread.current[:ejx_warnings] = []
    yield
    Thread.current[:ejx_warnings]
  ensure
    Thread.current[:ejx_warnings] = nil
    Warning[:deprecated] = deprecated
  end

  def expected_js(text)
    <<~JS.strip
      import {append as __ejx_append} from 'ejx';

      export default async function self (locals) {
          var __output = [], __promises = [];
          
          var __a = document.createElement("p");
          __a.setAttribute("title", "#{text}");
          __ejx_append("#{text}", __a, 'unescape', __promises);
          __ejx_append(__a, __output, 'unescape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  test "BINARY source is read as UTF-8 without warnings" do
    source = '<p title="café ✓">café ✓</p>'.b
    assert_equal Encoding::BINARY, source.encoding

    result = nil
    warnings = capture_warnings { result = EJX.compile(source) }

    assert_equal [], warnings
    assert_equal Encoding::UTF_8, result.encoding
    assert_equal expected_js('café ✓'), result.strip
  end

  test "UTF-8 source with a byte order mark" do
    result = EJX.compile("﻿<p title=\"café ✓\">café ✓</p>")
    assert_equal expected_js('café ✓'), result.strip

    result = EJX.compile("﻿<p title=\"café ✓\">café ✓</p>".b)
    assert_equal expected_js('café ✓'), result.strip
  end

  test "Latin-1 source is transcoded to UTF-8" do
    source = '<p title="café">café</p>'.encode(Encoding::ISO_8859_1)
    assert_equal "caf\xE9".b, source.b[-8..-5]

    result = EJX.compile(source)
    assert_equal Encoding::UTF_8, result.encoding
    assert_equal expected_js('café'), result.strip
  end

  test "BINARY source that isn't valid UTF-8 raises" do
    e = assert_raises EJX::TemplateError do
      EJX.compile("<p>caf\xE9</p>".b)
    end
    assert_equal "template source isn't valid UTF-8", e.message
  end

  test "invalid source raises with the filename" do
    e = assert_raises EJX::TemplateError do
      EJX::Template.new("<p>caf\xE9</p>".dup.force_encoding(Encoding::UTF_8), filename: 'views/cafe.ejx')
    end
    assert_equal "views/cafe.ejx: template source isn't valid UTF-8", e.message

    e = assert_raises EJX::TemplateError do
      EJX.compile("<p>\x82</p>".dup.force_encoding(Encoding::Shift_JIS), filename: 'views/sjis.ejx')
    end
    assert_equal "views/sjis.ejx: template source isn't valid Shift_JIS", e.message
  end

end
