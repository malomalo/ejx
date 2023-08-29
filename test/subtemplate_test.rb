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
          var __a_result = formTag(function () {
              var __b_promises = [];
              var __c = [];
              var __d = document.createElement("input");
              __d.setAttribute("type", "text");
              __ejx_append(__d, __c, 'unescape', __b_promises);
              var __e = document.createElement("input");
              __e.setAttribute("type", "submit");
              __ejx_append(__e, __c, 'unescape', __b_promises);
              return Promise.all(__b_promises).then(() => __c);
      });
          __ejx_append(__a_result, __output, 'escape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

  test "a subtemplate declared as a function" do
    result = EJX.compile(<<~DATA)
      <% function formTag (template) { %>
          <form><%= template() %></form>
      <%  } %>

      <%- formTag(function () { %>
        <input type="text" >
        <input type="submit" />
      <% }) %>
    DATA

    assert_equal(<<~JS.strip, result.strip)
      import {append as __ejx_append} from 'ejx';
      
      export default async function (locals) {
          var __output = [], __promises = [];
          
          function formTag (template) {
              var __a_promises = [];
              var __b = [];
              var __c = document.createElement("form");
              __ejx_append(template(), __c, 'escape', __a_promises);
              __ejx_append(" ", __c, 'unescape', __a_promises);
              __ejx_append(__c, __b, 'unescape', __a_promises);
              return __a_promises.length === 0 ? __b : Promise.all(__a_promises).then(() => __b);
          };
          var __d_result = formTag(function () {
              var __e_promises = [];
              var __f = [];
              var __g = document.createElement("input");
              __g.setAttribute("type", "text");
              __ejx_append(__g, __f, 'unescape', __e_promises);
              var __h = document.createElement("input");
              __h.setAttribute("type", "submit");
              __ejx_append(__h, __f, 'unescape', __e_promises);
              return Promise.all(__e_promises).then(() => __f);
      });
          __ejx_append(__d_result, __output, 'escape', __promises);

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
          
          var __a_results = [];
          var __a_promises = [];
          var __a_result = [1,2].forEach((...__args) => {
              var __b_results = [];
              var __b_promises = [];
              var __b_result = ((i) => {
                  var __c = [];
                  __ejx_append(i, __c, 'escape', __b_promises);
                  __b_results.push(__c);
                  return Promise.all(__b_promises).then(() => __c);
              })(...__args);
              __ejx_append(__b_results, __a_results, 'escape', __a_promises, __b_result);
              return __b_result;
          });
          __ejx_append(__a_results.flat(1), __output, 'escape', __promises, (__a_result instanceof Promise) ? __a_result.then(() => Promise.all(__a_promises).then(r => r.flat(1))) : Promise.all(__a_promises).then(r => r.flat(1)));

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
        
        var __a_results = [];
        var __a_promises = [];
        var __a_result = [1,2].forEach((...__args) => {
            var __b_results = [];
            var __b_promises = [];
            var __b_result = (async (i) => {
                var __c = [];
                __ejx_append(await i, __c, 'escape', __b_promises);
                __b_results.push(__c);
                await Promise.all(__b_promises);
                return __c;
            })(...__args);
            __ejx_append(__b_results, __a_results, 'escape', __a_promises, __b_result);
            return __b_result;
        });
        __ejx_append(__a_results.flat(1), __output, 'escape', __promises, (__a_result instanceof Promise) ? __a_result.then(() => Promise.all(__a_promises).then(r => r.flat(1))) : Promise.all(__a_promises).then(r => r.flat(1)));

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
          var __a_result = formTag(function (f) {
              var __b_promises = [];
              var __c = [];
              if (true) {
              __ejx_append("\\n      yes\\n  ", __c, 'unescape', __b_promises);
              } else {
              __ejx_append("\\n      no\\n  ", __c, 'unescape', __b_promises);
              }
              return Promise.all(__b_promises).then(() => __c);
      });
          __ejx_append(__a_result, __output, 'escape', __promises);

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
          
          var __a_result = formTag(function () {
              var __b_promises = [];
              var __c = [];
              var __d = document.createElement("input");
              __d.setAttribute("type", "text");
              __ejx_append(__d, __c, 'unescape', __b_promises);
              var __e = document.createElement("input");
              __e.setAttribute("type", "submit");
              __ejx_append(__e, __c, 'unescape', __b_promises);
              return Promise.all(__b_promises).then(() => __c);
      }, function () { return 1; });
          __ejx_append(__a_result, __output, 'escape', __promises);

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
              __ejx_append(__b, __a, 'unescape', __promises);
              return __a;
          }, function () {
              var __c = [];
              var __d = document.createElement("input");
              __d.setAttribute("type", "submit");
              __ejx_append(__d, __c, 'unescape', __promises);
              return __c;
          }), __output, 'escape', __promises);

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
          var __a_result = formTag(() => {
              var __b_promises = [];
              var __c = [];
              var __d = document.createElement("input");
              __d.setAttribute("type", "text");
              __ejx_append(__d, __c, 'unescape', __b_promises);
              var __e = document.createElement("input");
              __e.setAttribute("type", "submit");
              __ejx_append(__e, __c, 'unescape', __b_promises);
              return Promise.all(__b_promises).then(() => __c);
      });
          __ejx_append(__a_result, __output, 'escape', __promises);

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
              var __a_promises = [];
              var __b = [];
              var __c = document.createElement("input");
              __c.setAttribute("type", "text");
              __ejx_append(__c, __b, 'unescape', __a_promises);
              return __a_promises.length === 0 ? __b : Promise.all(__a_promises).then(() => __b);
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
        
        var __a_result = listenToRender(search, ['select', 'search'], selection => {
            var __b_promises = [];
            var __c = [];
            var __d_result = new Form(address, f => {
                var __e_promises = [];
                var __f = [];
                var __g = document.createElement("div");
                __g.setAttribute("class", "");
                __ejx_append(f.label('local_part', 'Street', {class:'text-bold block'}), __g, 'escape', __e_promises);
                __ejx_append(" ", __g, 'unescape', __e_promises);
                __ejx_append(f.text('local_part', {class:'uniformInput width-full'}), __g, 'escape', __e_promises);
                __ejx_append(" ", __g, 'unescape', __e_promises);
                __ejx_append(__g, __f, 'unescape', __e_promises);
                return Promise.all(__e_promises).then(() => __f);
            });
            __ejx_append(__d_result, __c, 'escape', __b_promises);
            return Promise.all(__b_promises).then(() => __c);
    });
        __ejx_append(__a_result, __output, 'escape', __promises);

        await Promise.all(__promises);
        return __output;
    }
    JS
  end
  
  test "output a subtemplate that assigns to a const with an if statement" do
    result = EJX.compile(<<~DATA)
      <% function renderer() { %>
        <% if (true) { %>
          <div>Hello World</div>
        <% } else { %>
          <div>NOT THIS</div>
        <% } %>
      <% } %>
      <%= renderer() %>
    DATA
    assert_equal(<<~JS.strip, result.strip)
    import {append as __ejx_append} from 'ejx';

    export default async function (locals) {
        var __output = [], __promises = [];
        
        function renderer() {
            var __a_promises = [];
            var __b = [];
            if (true) {
            __ejx_append(" ", __b, 'unescape', __a_promises);
            var __c = document.createElement("div");
            __ejx_append("Hello World", __c, 'unescape', __a_promises);
            __ejx_append(__c, __b, 'unescape', __a_promises);
            } else {
            __ejx_append(" ", __b, 'unescape', __a_promises);
            var __d = document.createElement("div");
            __ejx_append("NOT THIS", __d, 'unescape', __a_promises);
            __ejx_append(__d, __b, 'unescape', __a_promises);
            }
            return __a_promises.length === 0 ? __b : Promise.all(__a_promises).then(() => __b);
        };
        __ejx_append(renderer(), __output, 'escape', __promises);

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
              var __a_promises = [];
              var __b = [];
              var __c = document.createElement("tr");
              var __d = document.createElement("td");
              __ejx_append("Hello World", __d, 'unescape', __a_promises);
              __ejx_append(__d, __c, 'unescape', __a_promises);
              __ejx_append(__c, __b, 'unescape', __a_promises);
              return __a_promises.length === 0 ? __b : Promise.all(__a_promises).then(() => __b);
      }});
      __ejx_append(table, __output, 'escape', __promises);

          await Promise.all(__promises);
          return __output;
      }
    JS
  end

end