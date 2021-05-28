require 'test_helper'

class CompilationTest < Minitest::Test
  
  test "compile" do
    result = EJX.compile("Hello <%= name %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          __ejx_append(name, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "whitespace is preserved" do
    result = EJX.compile(<<~DATA)
      <%= 1 %>
      <%= 2 %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __ejx_append(1, __output, true, __promises);
          __output.push(" ");
          __ejx_append(2, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "whitespace before a html tag is preserved" do
    result = EJX.compile(<<~DATA)
      <%= 1 %>
      <span>span</span>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __ejx_append(1, __output, true, __promises);
          __output.push(" ");
          var __a = document.createElement("span");
          __ejx_append("span", __a, false, __promises);
          __ejx_append(__a, __output, false, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "compile simple template with a forEach" do
    result = EJX.compile(<<~DATA)
      <% records.forEach((record) => { %>
        <input type="text" >
        <input type="submit" />
      <% }); %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = [];
          __ejx_append(records.forEach((record) => {
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

  test "outputing a var" do
    result = EJX.compile("Hello <%= var x = 2; %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          var x = 2;
          __ejx_append(x, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
    
    result = EJX.compile("Hello <%= var x = 2 %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          var x = 2;
          __ejx_append(x, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "outputing a let" do
    result = EJX.compile("Hello <%= let x = 2; %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          let x = 2;
          __ejx_append(x, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
    
    result = EJX.compile("Hello <%= let x = 2 %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          let x = 2;
          __ejx_append(x, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "outputing a const" do
    result = EJX.compile("Hello <%= const x = 2; %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          const x = 2;
          __ejx_append(x, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
    
    result = EJX.compile("Hello <%= const x = 2 %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          const x = 2;
          __ejx_append(x, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "outputing normally with a var/const/let in the string" do
    result = EJX.compile("Hello <%= el(() => { var x = 2; let y = 3; const z = 4; return 5; } %>")
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __output.push("Hello ");
          __ejx_append(el(() => { var x = 2; let y = 3; const z = 4; return 5; }, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  
  test "more complex compile" do
    result = EJX.compile(<<~JS)
      <form class="uniformForm">
          <div class="form-group">
              <div class="uniformFloatingLabel">
                  <label for="email_address">Email Address</label>
                  <input type="text" class="pad-2x width-100-p" name="email_address" value="" id="email_address" autofocus>
              </div>
          </div>
          <div class="margin-v text-small text-center">
              <button class="reset js-reset-password text-gray-dark hover-blue">
                  Forgot Password?
              </button>
          </div>
      </form>
    JS

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';

      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = document.createElement("form");
          __a.setAttribute("class", "uniformForm");
          var __b = document.createElement("div");
          __b.setAttribute("class", "form-group");
          var __c = document.createElement("div");
          __c.setAttribute("class", "uniformFloatingLabel");
          var __d = document.createElement("label");
          __d.setAttribute("for", "email_address");
          __ejx_append("Email Address", __d, false, __promises);
          __ejx_append(__d, __c, false, __promises);
          var __e = document.createElement("input");
          __e.setAttribute("type", "text");
          __e.setAttribute("class", "pad-2x width-100-p");
          __e.setAttribute("name", "email_address");
          __e.setAttribute("value", "");
          __e.setAttribute("id", "email_address");
          __e.setAttribute("autofocus", "");
          __ejx_append(__e, __c, false, __promises);
          __ejx_append(__c, __b, false, __promises);
          __ejx_append(__b, __a, false, __promises);
          var __f = document.createElement("div");
          __f.setAttribute("class", "margin-v text-small text-center");
          var __g = document.createElement("button");
          __g.setAttribute("class", "reset js-reset-password text-gray-dark hover-blue");
          __ejx_append("\\n            Forgot Password?\\n        ", __g, false, __promises);
          __ejx_append(__g, __f, false, __promises);
          __ejx_append(__f, __a, false, __promises);
          __ejx_append(__a, __output, false, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  test "svg example" do
    result = EJX.compile(<<~JS)
      <svg xmlns="http://www.w3.org/2000/svg" width="526" height="233">
        <rect x="13" y="14" width="500" height="200" rx="50" ry="100" fill="none" stroke="blue" stroke-width="10" />
      </svg>
    JS

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          var __a = document.createElementNS("http://www.w3.org/2000/svg", "svg");
          __a.setAttribute("xmlns", "http://www.w3.org/2000/svg");
          __a.setAttribute("width", "526");
          __a.setAttribute("height", "233");
          var __b = document.createElementNS("http://www.w3.org/2000/svg", "rect");
          __b.setAttribute("x", "13");
          __b.setAttribute("y", "14");
          __b.setAttribute("width", "500");
          __b.setAttribute("height", "200");
          __b.setAttribute("rx", "50");
          __b.setAttribute("ry", "100");
          __b.setAttribute("fill", "none");
          __b.setAttribute("stroke", "blue");
          __b.setAttribute("stroke-width", "10");
          __ejx_append(__b, __a, false, __promises);
          __ejx_append(__a, __output, false, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

end
