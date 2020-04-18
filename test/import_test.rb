require 'test_helper'

class ImportTest < Minitest::Test

  test "quotes" do
    result = EJX.compile(<<~DATA)
      <% import x from y %>
      <% import a from z %>

      <%- x(function () { %>
        <input type="submit" />
        <%= a %>
      <% }) %>
    DATA
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      import x from y;
      import a from z;

      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = [];
          __ejx_append(x(function () {
              var __b = document.createElement("input");
              __b.setAttribute("type", "submit");
              __ejx_append(__b, __a, false, __promises);
              __ejx_append(a, __a, true, __promises);
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
end