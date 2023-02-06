class EJX::Template::Base
  
  attr_accessor :children, :imports

  def initialize(escape: nil)
    @children = []
    @escape = escape
    @imports = []
  end

  def to_module
    var_generator = EJX::Template::VarGenerator.new
    nested_promises = false
    
    output = if @escape
      "import {" + @escape.split('.').reverse.join(" as __ejx_append} from '") + "';\n"
    else
      "import {append as __ejx_append} from 'ejx';\n"
    end
    
    @imports.each do |import|
      output << import << "\n"
    end
    
    output << "\nexport default async function (locals) {\n"
    output << "    var __output = [], __promises = [];\n    \n"
    
    @children.each do |child|
      if child.is_a?(EJX::Template::Subtemplate) && child.has_nested_promises?
        nested_promises = true
      end
      nested_promises = true
      output << case child
      when EJX::Template::String
        "    __output.push(#{child.to_js});\n"
      else
        child.to_js(var_generator: var_generator)
      end
    end
    
    # if nested_promises
    #   output << "\n    var promises_length;"
    #   output << "\n    while (promises_length != __promises.length) {"
    #   output << "\n        promises_length = __promises.length;"
    #   output << "\n        await Promise.all(__promises);"
    #   output << "\n    }"
    # else
      output << "\n    await Promise.all(__promises);"
    # end

    output << "\n    return __output;"
    output << "\n}"
    
    output = <<-JS
    import {append as __ejx_append} from 'ejx';

    export default async function (locals) {
        var __output = [], __promises = [];
    
        const matrix = [
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
    ]
        __output.push(" ");
        var __a = document.createElement("table");
        var __b_results = [];
        var __b_promises = [];
        __ejx_append(matrix.forEach((...__args) => {
            var __c_results = [];
            var __c_promises = [];
            return __ejx_append((async (row) => {
                var __d = [];
                var __e = document.createElement("tr");
                row = await row
                var __f_results = [];
                var __f_promises = [];
                __ejx_append(row.forEach((...__args) => {
                    var __g_results = [];
                    var __g_promises = [];
                    return __ejx_append((async cell => {
                        var __h = [];
                        console.error('^^', cell)
                        __ejx_append(" ", __h, 'unescape', __g_promises);
                        const v = await cell
                        __ejx_append(" ", __h, 'unescape', __g_promises);
                        console.error('^^', v)
                        __ejx_append(" ", __h, 'unescape', __g_promises);
                        var __i = document.createElement("td");
                        __ejx_append(v, __i, 'escape', __g_promises);
                        __ejx_append(" ", __i, 'unescape', __g_promises);
                        __ejx_append(__i, __h, 'unescape', __g_promises);
                        __g_results.push(__h);
                        return __h;
                    })(...__args), __f_results, 'escape', __f_promises, __g_results, __g_promises, '&');
                }), __e, "escape", __c_promises, __f_results, __f_promises, '$');
                __ejx_append(__e, __d, 'unescape', __c_promises, undefined, __f_promises, 'LLLLLLLLLL');
                __c_results.push(__d);
                return __d;
            })(...__args), __b_results, 'escape', __b_promises, __c_results, __c_promises, '^');
        }), __a, "escape", __promises, __b_results, __b_promises, '*');
        __ejx_append(__a, __output, 'unescape', __promises);

        await Promise.all(__promises);
        return __output;
    }
    JS
    puts '-----------'
    puts output
    puts '-------------'

    output
  end

end