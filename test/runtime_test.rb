require 'test_helper'
require 'json'

class RuntimeTest < Minitest::Test

  def setup
    @node = Node.new(File.expand_path('../..', __FILE__))
    @node.npm_install('jsdom', 'jsdom-global')
  end

  def helpers
    return @ejx_helpers.path if defined?(@ejx_helpers)

    @ejx_helpers = Tempfile.open(['helpers', '.mjs'])
    @ejx_helpers.write(File.read(File.join(EJX::ASSET_DIR, 'ejx.js')))
    @ejx_helpers.flush
    @ejx_helpers.path
  end

  def template(source)
    file = Tempfile.open(['template', '.mjs'])
    file.write(EJX.compile(source).gsub(" from 'ejx';", " from '#{helpers}';"))
    file.flush
    file.path
  end

  def render(template, locals={})
    @node.exec_runtime(<<~JS)
      import 'jsdom-global/register.js';
      import template from "#{template}";

      var htmlEscapes = {
        '&': '&amp',
        '<': '&lt',
        '>': '&gt',
        '"': '&quot',
        "'": '&#39'
      }

      function toHTML(els) {
        if (Array.isArray(els)) {
          return els.map((i) => toHTML(i))
        } else {
          if (typeof els === 'string') {
            return els.replace(/[&<>"']/g, (chr) => htmlEscapes[chr])
          } else if (els instanceof Text) {
            return els.textContent;
          } else if (els instanceof Element || els instanceof Node) {
            return els.outerHTML;
          } else {
            return els
          }
        }
      }
      
      let result = template(#{JSON.generate(locals)})

      if (result instanceof Array) {
        result = Promise.all(result);
      }
      
      if (result instanceof Promise) {
        result.then((result) => {
          console.log(JSON.stringify({result: toHTML(result)}));
          process.exit(0);
        }, (e) => {
          console.log(JSON.stringify({error: [e.name, e.message, e.stack]}));
          process.exit(1);
        });
      } else {
        console.log(JSON.stringify({result: toHTML(result)}));
        process.exit(0);
      }
    JS
  end

  test "html tag value with interpolation in double quotes" do
    t1 = template('<div class="[[= locals.klass ]]"></div>')
    assert_equal(['<div class="name"></div>'], render(t1, klass: 'name'))
  end

  test "rendering another template in a template" do
    t1 = template('<div>t1</div>')
    t2 = template(<<~JS)
      <% import t1 from "#{t1}"; %>
      <%= t1() %>
      <div>t2</div>
    JS
    assert_equal(["<div>t1</div>", " ", "<div>t2</div>"], render(t2))
  end

  test "rendering a promise that returns a string in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve('hello world') }, 200); } ) %>
    EJX
    assert_equal(["hello world"], render(t1))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve('hello world') }, 200); } ) %></div>
    EJX
    assert_equal(["<div>hello world </div>"], render(t2))
  end

  test "rendering a promise that element in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createElement("div")) }, 200); } ) %>
    EJX
    assert_equal(["<div></div>"], render(t1))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createElement("div")) } , 200); } ) %></div>
    EJX
    assert_equal(["<div><div></div> </div>"], render(t2))
  end

  test "rendering a promise that returns an array of elements in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve([document.createElement("div"), document.createElement("div")]) }, 200); } ) %>
    EJX
    assert_equal(["<div></div>", "<div></div>"], render(t1))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve([document.createElement("div"), document.createElement("div")]) } , 200); } ) %></div>
    EJX
    assert_equal(["<div><div></div><div></div> </div>"], render(t2))
  end

  test "rendering a promise that returns an nested array of elements in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve([[document.createElement("div"), document.createElement("div")]]) }, 200); } ) %>
    EJX
    assert_equal([["<div></div>", "<div></div>"]], render(t1))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve([[document.createElement("div"), document.createElement("div")]]) } , 200); } ) %></div>
    EJX
    assert_equal(["<div><div></div><div></div> </div>"], render(t2))
  end

  test "rendering a promise that returns a undefined" do
    t1 = template(<<~EJX)
    Hello
    <span>
      <%= new Promise( (resolve) => { setTimeout(() => { resolve(undefined) }, 200); } ) %>
    </span>
    World
    EJX
    assert_equal(["Hello\n", "<span> </span>", "\nWorld"], render(t1))
  end

  test "rendering a promise that returns a Text Node in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createTextNode("my text node")) }, 200); } ) %>
    EJX
    assert_equal(["my text node"], render(t1))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createTextNode("my text node")) }, 200); } ) %></div>
    EJX
    assert_equal(["<div>my text node </div>"], render(t2))
  end

  test "rendering another template that has a promise inside a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve('hello') }, 200); } ) %>
    EJX
    t2 = template(<<~EJX)
      <% import t1 from "#{t1}"; %>
      <%= t1() %> world
    EJX
    assert_equal(["hello"], render(t1))
    assert_equal(["hello", " world"], render(t2))
  end

  test "including an HTML string" do
    t1 = template(<<~EJX)
      <%= '<div>t1</div>' %>
      <%- '<div>t2</div>' %>
    EJX
    assert_equal(["&ltdiv&gtt1&lt/div&gt", " ", "<div>t2</div>"], render(t1))
  end

  test "rendering a subtemplate in a promise" do
    t1 = template(<<~EJX)
      <% var formTag = function(template) {
           return new Promise( (resolve) => { setTimeout(() => { resolve(template()) }, 200); } );
         } %>

      <form>
      <% formTag(function () { %>
        <input type="text" >
        <input type="submit" />
      <% }) %>
      </form>
    EJX

    assert_equal([' ', '<form><input type="text"><input type="submit"></form>'], render(t1))
  end

  test "a forEach subtemplate" do
    t1 = template(<<~EJX)
      <% [1,2].forEach((i) => { %><%= i %><% }) %>
    EJX

    assert_equal([1,2], render(t1))
  end

  test "a map subtemplate" do
    t1 = template(<<~EJX)
      <%= [1,2].map((i) => { %><%= i %><% }) %>
    EJX

    assert_equal([1,2], render(t1))
  end

  test "a nested iterater subtemplate" do
    t1 = template(<<~EJX)
      <% const array = [[1,2], [3,4]] %>
      <table>
      <% array.forEach((row) => { %>
        <tr>
        <% row.forEach(cell => { %>
          <td><%= cell %></td>
        <% }) %>
        </tr>
      <% }) %>
      </table>
    EJX

    assert_equal([" ", "<table><tr><td>1 </td><td>2 </td></tr><tr><td>3 </td><td>4 </td></tr></table>"], render(t1))
  end

  test "a nested async iterater subtemplate" do
    t1 = template(<<~EJX)
      <% const matrix = [
        new Promise(x => setTimeout(() => x([
          new Promise(r => setTimeout(() => r(1), 5)),
          2
        ]), 5)),
        {
          forEach: iterator => new Promise(r => {
            [
              new Promise(r => setTimeout(() => r(3), 5)),
              new Promise(r => setTimeout(() => r(4), 5))
            ].forEach(iterator)
            r()
          })
        }
      ] %>
      <table>
      <% matrix.forEach(async (row) => { %>
        <tr>
        <% row = await row %>
        <% row.forEach(async cell => { %>
          <% const v = await cell %>
          <td><%= v %></td>
        <% }) %>
        </tr>
      <% }) %>
      </table>
    EJX

    assert_equal([" ", "<table><tr> <td>1 </td> <td>2 </td></tr><tr> <td>3 </td> <td>4 </td></tr></table>"], render(t1))
  end

  test "an forEach with an async subtemplate" do
    t1 = template(<<~EJX)
      <% [new Promise(r => r(1)),2].forEach(async (i) => { %>
        <span><%= await i %></span>
      <% }) %>
    EJX

    assert_equal(['<span>1 </span>', '<span>2 </span>'], render(t1))
  end

  test "an map with an async subtemplate" do
    t1 = template(<<~EJX)
      <%= [new Promise(r => {
          setTimeout(() => r(1), 5)
        }),2].map(async (i) => { %>
        <span><%= await i %></span>
      <% }) %>
    EJX

    assert_equal(['<span>1 </span>', '<span>2 </span>'], render(t1))
  end

  test "an iterater that is a promise" do
    t1 = template(<<~EJX)
      <% const collection = {forEach: template => new Promise(r => r([1,2].forEach(template)))} %>
      <% collection.forEach(async (i) => { %>
        <span><%= await i %></span>
      <% }) %>
    EJX

    assert_equal(['<span>1 </span>', '<span>2 </span>'], render(t1))
  end

  test "multiple sub templates" do
    t1 = template(<<~EJX)
      <% function formTag (a, b) { return [a(), b()]; } %>
      <%= formTag(function () { %>
        <input type="text" >
      <% }, function () { %>
        <input type="submit" />
      <% }) %>
    EJX

    assert_equal(['<input type="text">', '<input type="submit">'], render(t1))
  end
  
  test "assigning a sub template" do
    t1 = template(<<~EJX)
    <% function subTemplateA (x) { %>
      <a><%= x %></a>
    <% } %>
    <% const subTemplateB = function (x) { %>
      <b><%= x %></b>
    <% } %>
    <% const subTemplateC = (x) => { %>
      <c><%= x %></c>
    <% } %>
    <container>
      <%= subTemplateA('hello') %>
      <%= subTemplateB('world') %>
      <%= subTemplateC('it is me') %>
    </container>
    EJX

    assert_equal(['<container><a>hello </a> <b>world </b> <c>it is me </c> </container>'], render(t1))
  end
  
  test 'assignment test' do
    t1 = template(<<~EJX)
      <% async function createElement(elName, template) {
        var el = document.createElement(elName);
        el.append(...await template.children())
        return el;
      } %>

      <% const expense_table = createElement('table', {children: () => { %>
          <tr>
              <th>Type</th>
              <th>Amount</th>
              <th>Year</th>
              <th></th>
          </tr>
      <% }}) %>

      <%= expense_table %>
    EJX

    assert_equal(["<table><tr><th>Type</th><th>Amount</th><th>Year</th><th></th></tr></table>"], render(t1))
  end

  test 'another subtemplate test' do
    t1 = template(<<~EJX)
      <% var survey = {
            listings: {
              forEach: (fn) => { [
                {id: 1, attachments: { forEach: (fn) => [3,4].forEach(fn) }},
                {id: 2, attachments: { forEach: (fn) => [5,6].forEach(fn) }}
              ].forEach(fn) }
            }
      } %>

      <pages>
      <% survey.listings.forEach(async listing => { %>
          <page><%= listing.id %></page>
          <% await listing.attachments.forEach(async attachment => { %>
            <subpage><%= attachment %></subpage>
          <% }) %>
      <% }) %>
      </pages>
    EJX

    assert_equal([" ", "<pages><page>1 </page><subpage>3 </subpage><subpage>4 </subpage><page>2 </page><subpage>5 </subpage><subpage>6 </subpage></pages>"], render(t1))
  end

  test 'outputing a function that returns objects' do
    t1 = template(<<~EJX)
      <%  var x = [
            1,
            new Promise(r => { setTimeout(() => r(2), 5) })
          ];

      async function maskableTag(i, template) {
        const container = document.createElement('tr')
        container.append(...(await template(i)))
        return container;
      }
       %>

        <%= x.map((i) => { %>
          <%= maskableTag(i, (a) => { %>
            <%= a %>
          <% }) %>
        <% }) %>
    EJX

    assert_equal(["<tr>1</tr>", "<tr>2</tr>"], render(t1))
  end
  
  test "subtemplate is an option of a function" do
    t1 = template(<<~EJX)
    <% const createElement = (tagName, options) => {
      const tag = document.createElement(tagName)
      const content = options.content()
      content.forEach(el => tag.append(el))
      return tag;
    } %>
    <%= const table = createElement('table', {content: () => { %>
        <tr>
            <th></th>
            <th>Tenant</th>
            <th>Occupied Space</th>
            <th></th>
        </tr>
    <% }}) %>
    EJX
    
    assert_equal(['<table><tr><th></th><th>Tenant</th><th>Occupied Space</th><th></th></tr></table>'], render(t1))
  end
  
  test "rendering a proxy of a function" do
    t1 = template(<<~EJX)
    <%
    function neverEndingProxy(target) {
        return new Proxy(function () {}, {
            get: (fn, prop, receiver) => {
                if ( prop === 'then' ) {
                    return target.then.bind(target);
                } else {
                    return neverEndingProxy(target.then(t => {
                        if (typeof t[prop] === 'function') {
                            return t[prop].bind(t);
                        } else {
                            return t[prop];
                        }
                    }));
                }
            },
            apply: (fn, thisArg, args) => {
                return neverEndingProxy(target.then((t) => t(...args)));
            }
        });
    }
    %>Hello<span><%= neverEndingProxy(new Promise(r => {
        r({first_name: 'Rod Kimble'})
      })).first_name %></span>World
    EJX
    assert_equal(["Hello", "<span>Rod Kimble </span>", "World"], render(t1))
  end
end


require 'tempfile'
require 'open3'

class Node

  attr_accessor :npm_path

  def initialize(npm_path = nil)
    @npm_path = npm_path
  end

  def exec_runtime(script)
    Dir.chdir(npm_path) do
      Tempfile.open(['script', '.mjs'], npm_path) do |scriptfile|
        scriptfile.write(script)
        scriptfile.flush

        stdout, stderr, status = Open3.capture3(binary, scriptfile.path)

        STDERR.puts stderr if !stderr.empty?
        if status.success?
          begin
            JSON.parse(stdout)['result']
          rescue
            puts stdout, stderr
          end
        else
          begin
            result = JSON.parse(stdout)['error']
            if result[0] == 'SyntaxError'
              raise exec_syntax_error(result[1], scriptfile.path)
            else
              raise exec_runtime_error(result[0] + ': ' + result[1], scriptfile)
            end
          rescue JSON::ParserError
            raise exec_runtime_error(stdout + stderr, script)
          end
        end
      end
    end
  end

  def binary(cmd='node')
    if File.executable? cmd
      cmd
    else
      path = ENV['PATH'].split(File::PATH_SEPARATOR).find { |p|
        full_path = File.join(p, cmd)
        File.executable?(full_path) && File.file?(full_path)
      }
      if path.nil?
        raise RuntimeError, "Could not find executable #{cmd}"
      end
      File.expand_path(cmd, path)
    end
  end

  def exec_syntax_error(output, source_file)
    error = SyntaxError.new(output)
    lines = output.split("\n")
    lineno = lines[0][/\((\d+):\d+\)$/, 1] if lines[0]
    lineno ||= 1
    error.set_backtrace(["#{source_file}:#{lineno}"] + caller)
    error
  end

  def exec_runtime_error(output, source_file)
    error = RuntimeError.new(output)
    lines = output.split("\n")
    lineno = lines[0][/:(\d+)$/, 1] if lines[0]
    lineno ||= 1
    error.set_backtrace(["#{source_file}:#{lineno}"] + caller)
    error
  end

  def npm_install(*packages)
    return if packages.empty?
    packages.flatten!
    packages.select! do |package|
      !Dir.exist?(File.join(npm_module_path, package))
    end

    Dir.chdir(npm_path) do
      if !packages.empty?
        system("npm", "install", "--silent", *packages)
      end
    end
  end

  def npm_module_path(package=nil)
    File.join(*[npm_path, 'node_modules', package].compact)
  end

end
