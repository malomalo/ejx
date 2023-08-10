require 'stream_parser'

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
    super(source.strip)

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
          import = pm.strip
          import += ';' if !import.end_with?(';')
          @tree.first.imports << import
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
          quoted_value << EJX::Template::JS.new(pre_match.strip)
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
          quoted_value << EJX::Template::JS.new(pre_match.strip)
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
    @tree.first.to_module
  end

end