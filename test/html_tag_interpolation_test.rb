require 'test_helper'

class HTMLTagInterpolationTest < Minitest::Test
  
  test "html tag value with interpolation in double quotes" do
    result = EJX.compile('<div class="[[= klass ]]"></div>')
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = document.createElement("div");
          __a.setAttribute("class", klass);
          __ejx_append(__a, __output, false, __promises);

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
          __a.setAttribute("class", klass);
          __ejx_append(__a, __output, false, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

end