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

      export default async function self (locals) {
          var __output = [], __promises = [];
          
          var __a_result = x(function () {
              var __b_promises = [];
              var __c = [];
              var __d = document.createElement("input");
              __d.setAttribute("type", "submit");
              __ejx_append(__d, __c, 'unescape', __b_promises);
              __ejx_append(a, __c, 'escape', __b_promises);
              return Promise.all(__b_promises).then(() => __c);
      });
          __ejx_append(__a_result, __output, 'escape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
end