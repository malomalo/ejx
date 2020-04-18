require 'test_helper'

class SubtemplateTest < Minitest::Test

  test "quotes" do
    result = EJX.compile(<<~DATA)
      <% formTag = function(template) {
            var a = document.createElement("form");
            a.append.apply(a, template());
            return a
        } %>

      <%- formTag(function () { %>
        <input type="text" >
        <input type="submit" />
      <% }) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          formTag = function(template) {
            var a = document.createElement("form");
            a.append.apply(a, template());
            return a
        }
          var __a = [];
          __ejx_append(formTag(function () {
              var __b = document.createElement("input");
              __b.setAttribute("type", "text");
              __ejx_append(__b, __a, false, __promises);
              var __c = document.createElement("input");
              __c.setAttribute("type", "submit");
              __ejx_append(__c, __a, false, __promises);
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "with an else" do
    result = EJX.compile(<<~DATA)
      <% formTag = function(template) {
            var a = document.createElement("form");
            a.append.apply(a, template());
            return a
         } %>

      <%- formTag(function (f) { %>
        <% if (true) { %>
            yes
        <% } else { %>
            no
        <% } %>
      <% }) %>
    DATA
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          formTag = function(template) {
            var a = document.createElement("form");
            a.append.apply(a, template());
            return a
         }
          var __a = [];
          __ejx_append(formTag(function (f) {
              if (true) {
              __ejx_append("\\n      yes\\n  ", __a, false, __promises);
              } else {
              __ejx_append("\\n      no\\n  ", __a, false, __promises);
              }
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
end