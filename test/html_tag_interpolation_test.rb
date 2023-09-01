require 'test_helper'

class HTMLTagInterpolationTest < Minitest::Test
  
  test "html tag value with interpolation in double quotes" do
    result = EJX.compile('<div class="[[= klass ]]"></div>')

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';

      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = document.createElement("div");
          __a.setAttribute("class", [klass].join(""));
          __ejx_append(__a, __output, 'unescape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  test "html tag value with interpolation in single quotes" do
    result = EJX.compile("<div class='[[= klass ]]'></div>")

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';

      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = document.createElement("div");
          __a.setAttribute("class", [klass].join(""));
          __ejx_append(__a, __output, 'unescape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "html tag value with interpolation in middle of attribute" do
    result = EJX.compile(<<~EJX)
    <% const foo = true %>
    <div class="uniformLabel [[= foo ? 'disabled' : 'bold' ]] -yellow">Hello World</div>
    EJX
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          const foo = true
          __output.push(" ");
          var __a = document.createElement("div");
          __a.setAttribute("class", ["uniformLabel ", foo ? 'disabled' : 'bold', " -yellow"].join(""));
          __ejx_append("Hello World", __a, 'unescape', __promises);
          __ejx_append(__a, __output, 'unescape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

end