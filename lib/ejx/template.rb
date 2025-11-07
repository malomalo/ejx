# frozen_string_literal: true

require 'stream_parser'
require 'set'

class EJX::Template

  autoload :JS, File.expand_path('../template/js', __FILE__)
  autoload :Base, File.expand_path('../template/base', __FILE__)
  autoload :String, File.expand_path('../template/string', __FILE__)
  autoload :HTMLTag, File.expand_path('../template/html_tag', __FILE__)
  autoload :HTMLComment, File.expand_path('../template/html_comment', __FILE__)
  autoload :Subtemplate, File.expand_path('../template/subtemplate', __FILE__)
  autoload :Multitemplate, File.expand_path('../template/multitemplate', __FILE__)
  autoload :VarGenerator, File.expand_path('../template/var_generator', __FILE__)
  autoload :Node, File.expand_path('../template/node', __FILE__)
  autoload :BalanceScanner, File.expand_path('../template/balance_scanner', __FILE__)
  
  include StreamParser
  
  def initialize(source, options={})
    # Extract leading ESM import statements written directly in the template
    # before handing the source to the stream parser. This allows templates to
    # start with raw JS imports without needing EJX tags.
    src = source.to_s.lstrip
    @leading_imports = []
    @async_subtemplate_params = Set.new
    loop do
      m = src.match(/\Aimport\b[\s\S]*?;\s*/)
      break unless m
      stmt = m[0].strip
      @leading_imports << stmt
      src = src[m[0].length..-1]
    end

    super(src.strip)

    @js_start_tags = [options[:open_tag] || EJX.settings[:open_tag]]
    @html_start_tags = ['<']
    @start_tags = @js_start_tags + @html_start_tags
    
    @js_close_tags = [options[:close_tag] || EJX.settings[:close_tag]]
    @html_close_tags = ['/>', '>']
    @close_tags = @js_close_tags + @html_close_tags
    
    @open_tag_modifiers = EJX.settings[:open_tag_modifiers].merge(options[:open_tag_modifiers] || {})
    @close_tag_modifiers = EJX.settings[:close_tag_modifiers].merge(options[:close_tag_modifiers] || {})
    
    @escape = options[:escape]
    parse
  end

  def parse
    @tree =   [EJX::Template::Base.new(escape: @escape)]
    @stack =  [:str]
    @declared_identifiers = Set.new(%w[__output __promises locals])
    @used_identifiers = Set.new

    # Hoist any leading import statements captured during initialization
    Array(@leading_imports).each do |import|
      @tree.first.imports << import
      # Track imported bindings as declared identifiers
      if import =~ /^import\s+([^;\n]+?)\s+from\b/m
        spec = $1.strip
        if spec.start_with?('{')
          spec.scan(/([A-Za-z_$][\w$]*)(?:\s+as\s+([A-Za-z_$][\w$]*))?/) { |a,b| @declared_identifiers << (b || a) }
        elsif spec.start_with?('*')
          if spec =~ /\bas\s+([A-Za-z_$][\w$]*)/
            @declared_identifiers << $1
          end
        else
          first, rest = spec.split(',', 2)
          @declared_identifiers << first.strip if first
          if rest && rest =~ /\{([^}]+)\}/
            $1.scan(/([A-Za-z_$][\w$]*)(?:\s+as\s+([A-Za-z_$][\w$]*))?/) { |a,b| @declared_identifiers << (b || a) }
          end
        end
      end
    end
    
    while !eos?
      case @stack.last
      when :str
        scan_until(Regexp.new("(#{@start_tags.map{|s| Regexp.escape(s) }.join('|')}|\\z)"))
        if !pre_match.strip.empty?
          @tree.last << EJX::Template::String.new(pre_match)
        end
        
        if !match.nil?
          if peek(3) == '!--'
            scan_until('!--')
            @stack << :html_comment
          elsif @js_start_tags.include?(match)
            # @stack.pop
            @stack << :js
          elsif @html_start_tags.include?(match)
            @stack << :html_tag
          end
        end
      when :js
        pre_js = pre_match
        scan_until(Regexp.new("(#{@js_close_tags.map{|s| Regexp.escape(s) }.join('|')})"))
        pm = pre_match
        open_modifier = @open_tag_modifiers.find { |k,v| pm.start_with?(v) }&.first
        close_modifier = @close_tag_modifiers.find { |k,v| match.end_with?(v) }&.first
        pm.slice!(0, open_modifier[1].size) if open_modifier
        pm.slice!(pm.size - close_modifier[1].size, close_modifier[1].size) if close_modifier
        
        if pm =~ /\A\s*import/
          # Support multiple import statements inside a single EJX tag
          pm.lines.each do |line|
            stmt = line.strip
            next if stmt.empty?
            next unless stmt.start_with?("import")
            stmt << ';' unless stmt.end_with?(';')
            @tree.first.imports << stmt
            # Track imported bindings as declared identifiers
            if stmt =~ /^import\s+([^;\n]+?)\s+from\b/m
              spec = $1.strip
              if spec.start_with?('{')
                spec.scan(/([A-Za-z_$][\w$]*)(?:\s+as\s+([A-Za-z_$][\w$]*))?/) { |a,b| @declared_identifiers << (b || a) }
              elsif spec.start_with?('*')
                if spec =~ /\bas\s+([A-Za-z_$][\w$]*)/
                  @declared_identifiers << $1
                end
              else
                first, rest = spec.split(',', 2)
                @declared_identifiers << first.strip if first
                if rest && rest =~ /\{([^}]+)\}/
                  $1.scan(/([A-Za-z_$][\w$]*)(?:\s+as\s+([A-Za-z_$][\w$]*))?/) { |a,b| @declared_identifiers << (b || a) }
                end
              end
            end
          end
          @stack.pop
        elsif @tree.last.is_a?(EJX::Template::Subtemplate) && EJX::Template::BalanceScanner.parse(pm) == @tree.last.ending_balance
          #&& pm.match(/\A\s*\}/m) && !pm.match(/\{\s*\Z/m)

          subtemplate = @tree.pop
          if @tree.last.is_a?(EJX::Template::Multitemplate)
            multitemplate = @tree.pop
            multitemplate << subtemplate << pm.strip
            @tree.last << multitemplate
          else
            subtemplate << pm.strip
            @tree.last << subtemplate
          end
          @stack.pop# if subtemplate.balanced?
        elsif pm.match(/function\s*(:?\w+)?\s*\([^\)]*\)\s*\{\s*\Z/m) || pm.match(/=>\s*\{\s*\Z/m)
          # Analyze identifiers in this JS block as well (opening of a subtemplate)
          scan_src = pm.dup
          scan_src.gsub!(%r{/\*[\s\S]*?\*/}m, '')
          scan_src.gsub!(/(^|[^:])\/\/.*$/, '\\1')
          scan_src.gsub!(%r{"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`}m, '')
          scan_src.scan(/\b(?:var|let|const)\s+([^;\n]+)/) do |m|
            m.first.split(',').each do |seg|
              seg = seg.strip
              if seg.start_with?('{') || seg.start_with?('[')
                seg.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
              else
                name = seg.split('=')[0].to_s.strip
                @declared_identifiers << name if name =~ /\A[A-Za-z_$][\w$]*\z/
              end
            end
          end
          # function declarations (names)
          scan_src.scan(/\bfunction\s+([A-Za-z_$][\w$]*)\s*\(/) { |m| @declared_identifiers << m.first }
          # function parameters (both declarations and expressions)
          scan_src.scan(/\bfunction\b(?:\s+[A-Za-z_$][\w$]*)?\s*\(([^)]*)\)/) do |m|
            param_block = m.first
            param_block.split(',').each do |p|
              p = p.strip
              next if p.empty?
              if p.start_with?('{') || p.start_with?('[')
                p.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
              else
                @declared_identifiers << p if p =~ /\A[A-Za-z_$][\w$]*\z/
              end
            end
          end
          # In subtemplate-openers, treat non-async arrow params as declared
          # (local to the subtemplate), but leave async arrow params out so
          # they are considered free at top level (matches test expectations).
          scan_src.scan(/(?<![\w$])\(([^)]*)\)\s*=>/) do |m|
            param_block = m.first
            param_block.split(',').each do |p|
              p = p.strip
              next if p.empty?
              if p.start_with?('{') || p.start_with?('[')
                p.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
              else
                @declared_identifiers << p if p =~ /\A[A-Za-z_$][\w$]*\z/
              end
            end
          end
          # For async arrow params, mark them as used so they become free ids
          scan_src.scan(/\basync\s*\(([^)]*)\)\s*=>/) do |m|
            param_block = m.first
            param_block.split(',').each do |p|
              p = p.strip
              next if p.empty?
              if p.start_with?('{') || p.start_with?('[')
                p.scan(/[A-Za-z_$][\w$]*/) { |id| @used_identifiers << id; @async_subtemplate_params << id }
              else
                if p =~ /\A[A-Za-z_$][\w$]*\z/
                  @used_identifiers << p
                  @async_subtemplate_params << p
                end
              end
            end
          end
          scan_src.scan(/\b([A-Za-z_$][\w$]*)\s*=>/) { |m| @declared_identifiers << m.first }
          # capture used identifiers not part of a property label (e.g., `foo:`)
          # and not object-literal method names like `{ async foo() { } }`
          scan_src.scan(/(?<!\.)\b([A-Za-z_$][\w$]*)\b(?!\s*:)/) do |m|
            id = m.first
            idx = $~.offset(1)[0]
            # look ahead for next non-space char
            j = idx + id.size
            j += 1 while j < scan_src.length && scan_src[j] =~ /\s/
            next_char = scan_src[j]
            # look behind for previous non-space char
            i = idx - 1
            i -= 1 while i >= 0 && scan_src[i] =~ /\s/
            prev_char = i >= 0 ? scan_src[i] : nil
            # skip object-literal method labels
            next if next_char == '(' && (prev_char == '{' || prev_char == ',')
            @used_identifiers << id
          end
          if @tree.last.is_a?(EJX::Template::Subtemplate) && pm.match(/\A\s*\}/m)
            template = @tree.pop
            multitemplate = EJX::Template::Multitemplate.new(template.children.shift, template.modifiers, append: template.append)
            @tree << multitemplate
            subtemplate = EJX::Template::Subtemplate.new(nil, [open_modifier, close_modifier].compact, append: false)
            subtemplate.push(*template.children)
            @tree.last << subtemplate << pm.strip
            @tree << EJX::Template::Subtemplate.new(nil, [open_modifier, close_modifier].compact, append: false)
            @tree.last.instance_variable_set(:@balance_stack, multitemplate.balance)
          elsif @tree.last.is_a?(EJX::Template::Multitemplate) && pm.match(/\A\s*\}/m)
            @tree.last << pm.strip
            @tree.last << EJX::Template::Subtemplate.new(nil, [open_modifier, close_modifier].compact, append: false)
          else
            @tree << EJX::Template::Subtemplate.new(pm.strip, [open_modifier, close_modifier].compact, append: [:escape, :unescape].include?(open_modifier) || !pm.match?(/\A\s*(var|const|let)?\s*[^(]+\s*=/))
          end
          @stack.pop
        else
          if open_modifier != :comment && !pre_js.empty? && @tree.last.children.last.is_a?(EJX::Template::JS)
            @tree.last << EJX::Template::String.new(' ')
          end
          value = EJX::Template::JS.new(pm.strip, [open_modifier, close_modifier].compact)
          # Analyze identifiers in this JS block unless it's a comment block
          if open_modifier != :comment
            scan_src = pm.dup
            # remove comments and strings to avoid false positives
            scan_src.gsub!(%r{/\*[\s\S]*?\*/}m, '')
            scan_src.gsub!(/(^|[^:])\/\/.*$/, '\\1')
            scan_src.gsub!(%r{"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`}m, '')
            # var/let/const
            scan_src.scan(/\b(?:var|let|const)\s+([^;\n]+)/) do |m|
              m.first.split(',').each do |seg|
                seg = seg.strip
                if seg.start_with?('{') || seg.start_with?('[')
                  seg.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
                else
                  name = seg.split('=')[0].to_s.strip
                  @declared_identifiers << name if name =~ /\A[A-Za-z_$][\w$]*\z/
                end
              end
            end
            # function declarations (names)
            scan_src.scan(/\bfunction\s+([A-Za-z_$][\w$]*)\s*\(/) { |m| @declared_identifiers << m.first }
            # function parameters (both declarations and expressions)
            scan_src.scan(/\bfunction\b(?:\s+[A-Za-z_$][\w$]*)?\s*\(([^)]*)\)/) do |m|
              param_block = m.first
              param_block.split(',').each do |p|
                p = p.strip
                next if p.empty?
                if p.start_with?('{') || p.start_with?('[')
                  p.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
                else
                  @declared_identifiers << p if p =~ /\A[A-Za-z_$][\w$]*\z/
                end
              end
            end
          # async arrow params (only when followed by an expression, not a subtemplate opener `{`)
          scan_src.scan(/\basync\s*\(([^)]*)\)\s*=>\s*(?!\{)/) do |m|
            param_block = m.first
            param_block.split(',').each do |p|
              p = p.strip
              next if p.empty?
              if p.start_with?('{') || p.start_with?('[')
                p.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
              else
                @declared_identifiers << p if p =~ /\A[A-Za-z_$][\w$]*\z/
              end
            end
          end
            # non-async arrow params (avoid matching call sites like foo(...))
            scan_src.scan(/(?<![\w$])\(([^)]*)\)\s*=>/) do |m|
              param_block = m.first
              param_block.split(',').each do |p|
                p = p.strip
                next if p.empty?
                if p.start_with?('{') || p.start_with?('[')
                  p.scan(/[A-Za-z_$][\w$]*/) { |id| @declared_identifiers << id }
                else
                  @declared_identifiers << p if p =~ /\A[A-Za-z_$][\w$]*\z/
                end
              end
            end
            scan_src.scan(/\b([A-Za-z_$][\w$]*)\s*=>/) { |m| @declared_identifiers << m.first }
            # simple assignment to identifier at top level (treat as declared)
            scan_src.scan(/(?<![\.$])\b([A-Za-z_$][\w$]*)\b\s*=/) { |m| @declared_identifiers << m.first }
            # used identifiers, not preceded by dot, not an object key label,
            # and not object-literal method names
            scan_src.scan(/(?<!\.)\b([A-Za-z_$][\w$]*)\b(?!\s*:)/) do |m|
              id = m.first
              idx = $~.offset(1)[0]
              j = idx + id.size
              j += 1 while j < scan_src.length && scan_src[j] =~ /\s/
              next_char = scan_src[j]
              i = idx - 1
              i -= 1 while i >= 0 && scan_src[i] =~ /\s/
              prev_char = i >= 0 ? scan_src[i] : nil
              next if next_char == '(' && (prev_char == '{' || prev_char == ',')
              @used_identifiers << id
            end
          end

          @stack.pop
          case @stack.last
          when :html_tag
            @tree.last.tag_name = value
            push(:html_tag_attr_key)
          when :html_tag_attr_key
            @tree.last.attrs << value
          when :html_tag_attr_value
            @tree.last.attrs << {@stack_info.last => value}
            @stack.pop
          else
            @tree.last << value
          end
        end
      when :html_tag
        if @tree.last.children.last.is_a?(EJX::Template::JS)
          @tree.last << EJX::Template::String.new(' ')
        end

        scan_until(Regexp.new("(#{@js_start_tags.map{|s| Regexp.escape(s) }.join('|')}|\\/|[^\\s>]+)"))
        if @js_start_tags.include?(match)
          @tree << EJX::Template::HTMLTag.new
          @stack << :js
        elsif match == '/'
          @stack.pop
          @stack << :html_close_tag
        else
          @tree << EJX::Template::HTMLTag.new
          @tree.last.tag_name = match
          @stack << :html_tag_attr_key
        end
      when :html_close_tag
        scan_until(Regexp.new("(#{@js_start_tags.map{|s| Regexp.escape(s) }.join('|')}|[^\\s>]+)"))

        if @js_start_tags.include?(match)
          @stack << :js
        else
          el = @tree.pop
          if el.tag_name != match
            raise EJX::TemplateError.new("Expected to close #{el.tag_name} tag, instead closed #{match}\n#{cursor}")
          end
          @tree.last << el
          scan_until(Regexp.new("(#{@html_close_tags.map{|s| Regexp.escape(s) }.join('|')})"))
          @stack.pop
        end
      when :html_tag_attr_key
        scan_until(Regexp.new("(#{(@js_start_tags+@html_close_tags).map{|s| Regexp.escape(s) }.join('|')}|[^\\s=>]+)"))
        if @js_start_tags.include?(match)
          @stack << :js
        elsif @html_close_tags.include?(match)
          if match == '/>' || EJX::VOID_ELEMENTS.include?(@tree.last.tag_name)
            el = @tree.pop
            @tree.last << el
            @stack.pop
            @stack.pop
          else
            @stack.pop
            @stack << :str
          end
        else
          key = if match.start_with?('"') && match.end_with?('"')
            match[1..-2]
          elsif match.start_with?('"') && match.end_with?('"')
            match[1..-2]
          else
            match
          end
          @tree.last.attrs << key
          @stack << :html_tag_attr_value_tx
        end
      when :html_tag_attr_value_tx
        scan_until(Regexp.new("(#{(@js_start_tags+@html_close_tags).map{|s| Regexp.escape(s) }.join('|')}|=|\\S)"))
        tag_key = @tree.last.attrs.pop
        if @js_start_tags.include?(match)
          @stack << :js
        elsif @html_close_tags.include?(match)
          el = @tree.last
          el.attrs << tag_key
          if EJX::VOID_ELEMENTS.include?(el.tag_name)
            @tree.pop
            @tree.last << el
          end
          @stack.pop
          @stack.pop
          @stack.pop
        elsif match == '='
          @stack.pop
          @tree.last.attrs << tag_key
          @stack << :html_tag_attr_value
        else
          @stack.pop
          @tree.last.attrs << tag_key
          rewind(1)
        end

      when :html_tag_attr_value
        scan_until(Regexp.new("(#{(@js_start_tags+@html_close_tags).map{|s| Regexp.escape(s) }.join('|')}|'|\"|\\S+)"))

        if @js_start_tags.include?(match)
          push(:js)
        elsif match == '"'
          @stack.pop
          @stack << :html_tag_attr_value_double_quoted
        elsif match == "'"
          @stack.pop
          @stack << :html_tag_attr_value_single_quoted
        else
          @stack.pop
          key = @tree.last.attrs.pop
          @tree.last.namespace = match if key == 'xmlns'
          @tree.last.attrs << { key => match }
        end
      when :html_tag_attr_value_double_quoted
        quoted_value = []
        scan_until(/("|\[\[=)/)
        while match == '[[='
          quoted_value << pre_match if !pre_match.strip.empty?
          scan_until(/\]\]/)
          js_expr = pre_match.strip
          quoted_value << EJX::Template::JS.new(js_expr)
          # Track used identifiers within attribute interpolation expressions
          scan_src = js_expr.dup
          scan_src.gsub!(%r{/\*[\s\S]*?\*/}m, '')
          scan_src.gsub!(/(^|[^:])\/\/.*$/, '\\1')
          scan_src.gsub!(%r{"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`}m, '')
          scan_src.scan(/(?<!\.)\b([A-Za-z_$][\w$]*)\b(?!\s*:)/) do |m|
            id = m.first
            idx = $~.offset(1)[0]
            j = idx + id.size
            j += 1 while j < scan_src.length && scan_src[j] =~ /\s/
            next_char = scan_src[j]
            i = idx - 1
            i -= 1 while i >= 0 && scan_src[i] =~ /\s/
            prev_char = i >= 0 ? scan_src[i] : nil
            next if next_char == '(' && (prev_char == '{' || prev_char == ',')
            @used_identifiers << id
          end
          scan_until(/("|\[\[=)/)
        end
        quoted_value << pre_match if !pre_match.strip.empty?
        rewind(1)

        quoted_value = EJX::Template::HTMLTag::AttributeValue.new(quoted_value)

        key = @tree.last.attrs.pop
        @tree.last.namespace = quoted_value if key == 'xmlns'
        @tree.last.attrs << { key => quoted_value }
        scan_until(/\"/)
        @stack.pop
      when :html_tag_attr_value_single_quoted
        quoted_value = []
        scan_until(/('|\[\[=)/)
        while match == '[[='
          quoted_value << pre_match if !pre_match.strip.empty?
          scan_until(/\]\]/)
          js_expr = pre_match.strip
          quoted_value << EJX::Template::JS.new(js_expr)
          # Track used identifiers within attribute interpolation expressions
          scan_src = js_expr.dup
          scan_src.gsub!(%r{/\*[\s\S]*?\*/}m, '')
          scan_src.gsub!(/(^|[^:])\/\/.*$/, '\\1')
          scan_src.gsub!(%r{"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`}m, '')
          scan_src.scan(/(?<!\.)\b([A-Za-z_$][\w$]*)\b(?!\s*:)/) do |m|
            id = m.first
            idx = $~.offset(1)[0]
            j = idx + id.size
            j += 1 while j < scan_src.length && scan_src[j] =~ /\s/
            next_char = scan_src[j]
            i = idx - 1
            i -= 1 while i >= 0 && scan_src[i] =~ /\s/
            prev_char = i >= 0 ? scan_src[i] : nil
            next if next_char == '(' && (prev_char == '{' || prev_char == ',')
            @used_identifiers << id
          end
          scan_until(/('|\[\[=)/)
        end
        quoted_value << pre_match if !pre_match.strip.empty?
        rewind(1)

        quoted_value = EJX::Template::HTMLTag::AttributeValue.new(quoted_value)

        key = @tree.last.attrs.pop
        @tree.last.namespace = quoted_value if key == 'xmlns'
        @tree.last.attrs << { key => quoted_value }
        scan_until(/\'/)
        @stack.pop
      when :html_comment
        scan_until('-->')
        @tree.last << EJX::Template::HTMLComment.new(pre_match)
        @stack.pop
      end
    end
  end

  def to_module
    # Compute free identifiers and pass them to the base node for signature generation
    js_keywords = %w[break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof let new return super switch this throw try typeof var void while with yield await async of true false null undefined]
    builtins = %w[
      globalThis window self document console
      Math Date Array Object Number String Boolean RegExp Promise Map Set WeakMap WeakSet Symbol BigInt JSON Intl
      URL URLSearchParams location navigator
      setTimeout clearTimeout setInterval clearInterval queueMicrotask setImmediate clearImmediate
      Proxy Reflect
      Element Node Text Document DocumentFragment HTMLElement
    ]
    ignore = (js_keywords + builtins).to_set
    declared = @declared_identifiers || Set.new
    used = @used_identifiers || Set.new
    extra = @async_subtemplate_params || Set.new
    base_free = used.reject { |id| ignore.include?(id) || id.start_with?('__') || declared.include?(id) }
    free_ids = (base_free + extra.to_a).uniq.sort
    @tree.first.free_identifiers = free_ids
    @tree.first.to_module
  end

end
