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
* `self` references the template function

The functions compiled with EJX will return an array containing `Node` objects
and/or `DOMString` which can be appended to a Node via `Node.append(...)`

Examples
--------

To compile an EJX template into a Javascript module pass the template to `EJX.compile`:

```ruby
    EJX.compile("Hello <span><%= name %></span>")
    # => import {append as __ejx_append} from 'ejx';
    # => 
    # => export default async function self (locals) {
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

Configuration Options
---------------------

EJX supports a small set of compile-time options. You can pass these via Ruby (`EJX.compile(source, options)`) or through the esbuild plugin (flat options on `ejxPlugin({ ... })`).

| Option                 | Type    | Default    | Description                                                                                  | Example                         |
|------------------------|---------|------------|----------------------------------------------------------------------------------------------|---------------------------------|
| `open_tag`             | String  | `<%`       | Opening delimiter for EJX tags.                                                              | `'<{'`                          |
| `close_tag`            | String  | `%>`       | Closing delimiter for EJX tags.                                                              | `'}>'`                          |
| `open_tag_modifiers`   | Object  | `{ escape: '=', unescape: '-', comment: '#', literal: '%' }` | Maps prefix characters used right after `open_tag` to behaviors.                              | `{ escape: '=', unescape: '-' }`|
| `close_tag_modifiers`  | Object  | `{ trim: '-', literal: '%' }` | Maps suffix characters used before `close_tag` to behaviors (e.g., `-` to trim).              | `{ trim: '-' }`                 |
| `escape`               | String? | `nil`       | Custom append/escape import in the form `'<modulePath>.<exportName>'` used for output writes. | `'@app/ejx.append'`             |

Notes:
- Modifiers apply like: `<%=` (escape), `<%-` (unescape/raw), `<%#` (comment), `<%%` (literal tag). The `trim` close modifier is written before `close_tag`, e.g. `<% code -%>`.
- When using the esbuild plugin, all flat keys passed to `ejxPlugin({ ... })` are forwarded to `EJX.compile`. The only reserved key is `ruby`, which selects the Ruby executable.

Propshaft
---------

When used in a Rails app with Propshaft, this gem provides a compiler so you can import EJX templates directly from JavaScript. Place templates anywhere on your asset load paths with one of these extensions:

- .ejx, .ejs
- .ejx.html, .ejs.html
- .html.ejx, .html.ejs

Then import them like any other ES module:

```js
import template from "application/components/button.ejx";

document.body.append(...(await template({ label: "Click me" })));
```

At boot, if Propshaft is present, the compiler registers automatically. The templates are compiled to JavaScript with a `.js` destination extension.

Importmap
---------

This gem ships a Railtie that augments `importmap-rails` so EJX/EJS templates are discovered by `pin_all_from` and added to the import map. Supported source extensions:

- `.ejx`, `.ejs`
- `.ejx.html`, `.ejs.html`
- `.html.ejx`, `.html.ejs`

Usage in `config/importmap.rb` stays the same:

```ruby
pin_all_from "app/assets", under: "application"
# Files like app/assets/application/components/button.html.ejx
# are discovered and pinned. Importmap will point to the template path and
# Propshaft serves compiled JavaScript with the correct content type.

Additionally, the Railtie automatically pins the EJX runtime helper so compiled templates can import it:

```ruby
# Added automatically (no action needed):
pin "ejx", to: "ejx.js"
```

JsBundling (esbuild)
--------------------

To compile EJX/EJS during jsbundling-rails builds with esbuild, this gem provides a generator that sets up an esbuild plugin and config:

```bash
bin/rails generate ejx:install_jsbundling
npm run build        # or yarn build / bun run build
```

What it does:
- Adds `esbuild-ejx-plugin.js` (compiles `.ejx`, `.ejs`, `.html.ejx`, `.html.ejs` via Ruby EJX)
- Creates or updates `esbuild.config.mjs` to use the plugin
- Updates `package.json` scripts to run the config
- Vendors the EJX runtime to `app/javascript/vendor/ejx.js` and aliases the bare import `ejx` to it so compiled templates can `import { append } from 'ejx'`.

Then you can import templates the same way:

```js
import template from "./templates/show.html.ejs";
document.body.append(...(await template({ name: "World" })));
```

Configuring EJX options with esbuild
------------------------------------

Pass EJX options to the plugin in `esbuild.config.mjs`. These are forwarded to `EJX.compile(source, options)`:

```js
// esbuild.config.mjs
import esbuild from 'esbuild'
import ejxPlugin from './esbuild-ejx-plugin.js'

const options = {
  entryPoints: ["app/javascript/application.js"],
  bundle: true,
  outdir: "app/assets/builds",
  plugins: [
    ejxPlugin({
      // All EJX options are supported (JSON-serializable)
      open_tag: '<{',
      close_tag: '}>'
    })
  ]
}

await esbuild.build(options)
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

export default async function self (locals) {
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
