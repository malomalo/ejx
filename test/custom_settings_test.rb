require 'test_helper'

class CustomSettingsTest < Minitest::Test

  test "compile with custom defults" do
    old_defaults = EJX.settings
    EJX.settings = {
      open_tag: '{{',
      close_tag: '}}',
  
      open_tag_modifiers: {
        escape: '=',
        unescape: '-',
        comment: '#',
        literal: '%'
      },

      close_tag_modifiers: {
        trim: '-',
        literal: '%'
      },
      escape: nil
    }

    result = EJX.compile("Hello {{= name }}")
    assert_equal(<<~JS.strip, result)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          __ejx_append(name, __output, 'escape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  ensure
    EJX.settings = old_defaults
  end

  test "compile with custom syntax" do
    standard_result = EJX.compile("Hello <%= name %>")
    question_result = EJX.compile("Hello <?= name ?>", open_tag: '<?', close_tag: '?>')
    assert_equal standard_result, question_result
  end
end