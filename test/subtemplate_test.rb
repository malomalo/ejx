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
  
  test "an iterater with an async subtemplate" do
    result = EJX.compile(<<~DATA)
      <% [1,2].forEach(async (i) => { %>
        <%= await i %>
      <% }) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
    import {append as __ejx_append} from 'ejx';

    export default async function (locals) {
        var __output = [], __promises = [];
        
        var __a = [];
        __ejx_append([1,2].forEach(async (i) => {
            var __b = [];
            var resolve, error;
            var thisPromise = new Promise((r, e) => {
              resolve = r;
              error = e;
            });
            __promises.push(thisPromise);
            try {
                __ejx_append(await i, __b, true, __promises);
                __a.push(__b);
                resolve()
            } catch (e) {
                error(e)
            }
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
  
  test "multiple subtemplates" do
    result = EJX.compile(<<~DATA)
      <%= formTag(function () { %>
        <input type="text" >
      <% }, function () { %>
        <input type="submit" />
      <% }) %>
    DATA
    
    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          __ejx_append(formTag(function () {
              var __a = [];
              var __b = document.createElement("input");
              __b.setAttribute("type", "text");
              __ejx_append(__b, __a, false, __promises);
              return __a;
          }, function () {
              var __c = [];
              var __d = document.createElement("input");
              __d.setAttribute("type", "submit");
              __ejx_append(__d, __c, false, __promises);
              return __c;
          }), __output, true, __promises);

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
              var __a = [];
              var __b = document.createElement("input");
              __b.setAttribute("type", "text");
              __ejx_append(__b, __a, false, __promises);
              return __a;
          });

          await Promise.all(__promises);
          return __output;
      }
    JS
  end
  
  test "nested subtemplates" do
    result = EJX.compile(<<~DATA)
      <%= listenToRender(search, ['select', 'search'], selection => { %>
          <%= new Form(address, f => { %>
            <div class="">
                <%= f.label('local_part', 'Street', {class:'text-bold block'}) %>
                <%= f.text('local_part', {class:'uniformInput width-full'}) %>
            </div>
          <% }) %>
      <% }) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
    import {append as __ejx_append} from 'ejx';

    export default async function (locals) {
        var __output = [], __promises = [];
        
        var __a = [];
        __ejx_append(listenToRender(search, ['select', 'search'], selection => {
            var __b = [];
            var __c = [];
            __ejx_append(new Form(address, f => {
                var __d = [];
                var __e = document.createElement("div");
                __e.setAttribute("class", "");
                __ejx_append(f.label('local_part', 'Street', {class:'text-bold block'}), __e, true, __promises);
                __ejx_append(" ", __e, false, __promises);
                __ejx_append(f.text('local_part', {class:'uniformInput width-full'}), __e, true, __promises);
                __ejx_append(" ", __e, false, __promises);
                __ejx_append(__e, __d, false, __promises);
                __c.push(__d);
                return __d;
            }), __b, true, __promises, __c);
            __a.push(__b);
            return __b;
        }), __output, true, __promises, __a);

        await Promise.all(__promises);
        return __output;
    }
    JS
  end
  
  test "output a subtemplate that assigns to a const" do
    result = EJX.compile(<<~DATA)
      <%= const table = createElement('table', {children: () => { %>
          <tr><td>Hello World</td></tr>
      <% }}) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          const table = createElement('table', {children: () => {
              var __a = [];
              var __b = document.createElement("tr");
              var __c = document.createElement("td");
              __ejx_append("Hello World", __c, false, __promises);
              __ejx_append(__c, __b, false, __promises);
              __ejx_append(__b, __a, false, __promises);
              return __a;
          }});
          __ejx_append(table, __output, true, __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

end