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
      
      #{"setTimeout(() => {" if locals[:timeout]}

      if (result instanceof Promise) {
        result.then((result) => {
          console.log(JSON.stringify({result: toHTML(result)}));
          process.exit(0);
        }, (e) => {
          console.log(JSON.stringify({error: [e.name, e.message]}));
          process.exit(1);
        });
      } else {
        console.log(JSON.stringify({result: toHTML(result)}));
        process.exit(0);
      }
      #{"}, #{locals[:timeout]})" if locals[:timeout]}
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
      <%= new Promise( (resolve) => { setTimeout(() => { resolve('hello world') }, 10); } ) %>
    EJX
    assert_equal(["hello world"], render(t1, timeout: 20))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve('hello world') }, 10); } ) %></div>
    EJX
    assert_equal(["<div>hello world </div>"], render(t2, timeout: 20))
  end

  test "rendering a promise that element in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createElement("div")) }, 10); } ) %>
    EJX
    assert_equal(["<div></div>"], render(t1, timeout: 20))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createElement("div")) } , 10); } ) %></div>
    EJX
    assert_equal(["<div><div></div> </div>"], render(t2, timeout: 20))
  end

  test "rendering a promise that returns an array of elements in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve([document.createElement("div"), document.createElement("div")]) }, 10); } ) %>
    EJX
    assert_equal(["<div></div>", "<div></div>"], render(t1, timeout: 20))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve([document.createElement("div"), document.createElement("div")]) } , 10); } ) %></div>
    EJX
    assert_equal(["<div><div></div><div></div> </div>"], render(t2, timeout: 20))
  end

  test "rendering a promise that returns an nested array of elements in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve([[document.createElement("div"), document.createElement("div")]]) }, 10); } ) %>
    EJX
    assert_equal([["<div></div>", "<div></div>"]], render(t1, timeout: 20))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve([[document.createElement("div"), document.createElement("div")]]) } , 10); } ) %></div>
    EJX
    assert_equal(["<div><div></div><div></div> </div>"], render(t2, timeout: 20))
  end

  test "rendering a promise that returns a undefined" do
    t1 = template(<<~EJX)
    Hello
    <span>
      <%= new Promise( (resolve) => { setTimeout(() => { resolve(undefined) }, 10); } ) %>
    </span>
    World
    EJX
    assert_equal(["Hello\n", "<span> </span>", "\nWorld"], render(t1, timeout: 20))
  end

  test "rendering a promise that returns a Text Node in a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createTextNode("my text node")) }, 10); } ) %>
    EJX
    assert_equal(["my text node"], render(t1, timeout: 20))

    t2 = template(<<~EJX)
      <div><%= new Promise( (resolve) => { setTimeout(() => { resolve(document.createTextNode("my text node")) }, 10); } ) %></div>
    EJX
    assert_equal(["<div>my text node </div>"], render(t2, timeout: 20))
  end

  test "rendering another template that has a promise inside a template" do
    t1 = template(<<~EJX)
      <%= new Promise( (resolve) => { setTimeout(() => { resolve('hello') }, 10); } ) %>
    EJX
    t2 = template(<<~EJX)
      <% import t1 from "#{t1}"; %>
      <%= t1() %> world
    EJX
    assert_equal(["hello"], render(t1, timeout: 20))
    assert_equal(["hello", " world"], render(t2, timeout: 50))
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
           return new Promise( (resolve) => { setTimeout(() => { resolve(template()) }, 10); } );
         } %>

      <form>
      <% formTag(function () { %>
        <input type="text" >
        <input type="submit" />
      <% }) %>
      </form>
    EJX

    assert_equal([' ', '<form><input type="text"><input type="submit"></form>'], render(t1, timeout: 20))
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
          <td><%= await cell %></td>
        <% }) %>
        </tr>
      <% }) %>
      </table>
    EJX

    assert_equal([" ", "<table><tr><td>1 </td><td>2 </td></tr><tr><td>3 </td><td>4 </td></tr></table>"], render(t1, timeout: 200))

    #TODO test array.forEach lower in nesting inside promises, might result in top Promises.all, which appends overall array, running before Promises.all of lower level append
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

    assert_equal(['<span>1 </span>', '<span>2 </span>'], render(t1, timeout: 10))
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

        if status.success?
          STDERR.puts stderr if !stderr.empty?
          JSON.parse(stdout)['result']
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
