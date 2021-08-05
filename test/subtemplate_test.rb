require 'test_helper'

class SubtemplateTest < Minitest::Test

  test "a simple subtemplate" do
    result = EJX.compile(<<~DATA)
      <% formTag = function(template) {
            var a = document.createElement("form");
            a.append.apply(a, template());
            return a;
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
            return a;
        }
          var __a = [];
          __ejx_append(formTag(function () {
              var __b = [];
              var __c = document.createElement("input");
              __c.setAttribute("type", "text");
              __ejx_append(__c, __b, false, __promises);
              var __d = document.createElement("input");
              __d.setAttribute("type", "submit");
              __ejx_append(__d, __b, false, __promises);
              __a.push(__b);
              return __b;
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  test "a iterater subtemplate" do
    result = EJX.compile(<<~DATA)
      <% [1,2].forEach((i) => { %>
        <%= i %>
      <% }) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = [];
          __ejx_append([1,2].forEach((i) => {
              var __b = [];
              __ejx_append(i, __b, true, __promises);
              __a.push(__b);
              return __b;
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  test "a simple subtemplate with a if inside it" do
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
              var __b = [];
              if (true) {
              __ejx_append("\\n      yes\\n  ", __b, false, __promises);
              } else {
              __ejx_append("\\n      no\\n  ", __b, false, __promises);
              }
              __a.push(__b);
              return __b;
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "subtemplate as first option" do
    result = EJX.compile(<<~DATA)
      <%= formTag(function () { %>
        <input type="text" >
        <input type="submit" />
      <% }, function () { return 1; }) %>
    DATA
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = [];
          __ejx_append(formTag(function () {
              var __b = [];
              var __c = document.createElement("input");
              __c.setAttribute("type", "text");
              __ejx_append(__c, __b, false, __promises);
              var __d = document.createElement("input");
              __d.setAttribute("type", "submit");
              __ejx_append(__d, __b, false, __promises);
              __a.push(__b);
              return __b;
          }, function () { return 1; }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "a simple subtemplate with new function syntax" do
    result = EJX.compile(<<~DATA)
      <% formTag = function(template) {
            var a = document.createElement("form");
            a.append.apply(a, template());
            return a;
        } %>

      <%- formTag(() => { %>
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
            return a;
        }
          var __a = [];
          __ejx_append(formTag(() => {
              var __b = [];
              var __c = document.createElement("input");
              __c.setAttribute("type", "text");
              __ejx_append(__c, __b, false, __promises);
              var __d = document.createElement("input");
              __d.setAttribute("type", "submit");
              __ejx_append(__d, __b, false, __promises);
              __a.push(__b);
              return __b;
          }), __output, true, __promises, __a);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "a subtemplate that assigns to a var" do
    result = EJX.compile(<<~DATA)
      <% var x = [1,2].map((n) => { %>
        <input type="text" >
      <% }) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          var x = [1,2].map((n) => {
              var __b = [];
              var __c = document.createElement("input");
              __c.setAttribute("type", "text");
              __ejx_append(__c, __b, false, __promises);
              return __b;
          });

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
end