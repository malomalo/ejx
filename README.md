EJX (Embedded JavaScript) template compiler for Ruby
====================================================

EJX templates embed JavaScript code inside `<% ... %>` tags, much like ERB. This
library is inspired by [Underscore.js](https://underscorejs.org)'s
[`_.template` function](https://underscorejs.org/#template) and
[JSX](https://reactjs.org/docs/jsx-in-depth.html), but without the virtual DOM.

The EJX tag syntax is as follows:

* `<% ... %>` silently evaluates the statement inside the tags.
* `<%= ... %>` evaluates the expression inside the tags, escapes and inserts it
               into the template output.
* `<%- ... %>` behaves like `<%= ... %>` but does not escape it's output.

The functions compiled with EJX will return an array containing `Node` objects
and/or `DOMString` which can be appended to a Node via `Node.append(...)`

Examples
--------

To compile an EJX template into a Javascript module pass the template to `EJX.compile`:

```ruby
    EJX.compile("Hello <span><%= name %></span>")
    # => import {append as __ejx_append} from 'ejx';
    # => 
    # => export default async function (locals) {
    # =>     var __output = [], __promises = [];
    # => 
    # =>     __output.push("Hello ");
    # =>     var __a = document.createElement("span");
    # =>     __ejx_append(name, __a, true, __promises);
    # =>     __ejx_append(__a, __output, false, __promises);
    # => 
    # =>     await Promise.all(__promises);
    # =>     return __output;
    # => }
    JS
```

If a evalation tag (`<%=` or `<%-`) ends with an opening of a function, the
function returns a compiled template. For example:

```erb
<%  formTag = function(template) {
        var a = document.createElement("form");
        a.append.apply(a, template());
        return a;
    } %>

<%= formTag(function () { %>
  <input type="submit" />
<% }) %>
```

generates:

```js
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
        var __b = document.createElement("input");
        __b.setAttribute("type", "submit");
        __ejx_append(__b, __a, false, __promises);
    }), __output, true, __promises, __a);

    await Promise.all(__promises);
    return __output;
}
```