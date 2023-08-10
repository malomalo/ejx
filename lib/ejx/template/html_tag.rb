class EJX::Template::HTMLTag < EJX::Template::Node

  autoload :AttributeValue, File.expand_path('../html_tag/attribute_value', __FILE__)
  
  attr_accessor :tag_name, :attrs, :namespace

  def initialize
    super
    @attrs = []
  end

  def to_s
    @value
  end

  def inspect
    "#<EJX::HTMLTag:#{self.object_id} @tag_name=#{tag_name}>"
  end
  
  def to_js(append: "__output", var_generator:, indentation: 4, namespace: nil, promises: '__promises')
    namespace ||= self.namespace
    
    output_var = var_generator.next
    js = "#{' '*indentation}var #{output_var} = document.createElement"
    js << if namespace
      "NS(#{namespace.to_js}, #{JSON.generate(tag_name)});\n"
    else
      "(#{JSON.generate(tag_name)});\n"
    end

    @attrs.each do |attr|
      if attr.is_a?(Hash)
        attr.each do |k, v|
          js << "#{' '*indentation}#{output_var}.setAttribute(#{JSON.generate(k)}, #{v.to_js});\n"
        end
      else
        js << "#{' '*indentation}#{output_var}.setAttribute(#{JSON.generate(attr)}, \"\");\n"
      end
    end

    @children.each do |child|
      js << if child.is_a?(EJX::Template::String)
        "#{' '*indentation}__ejx_append(#{child.to_js}, #{output_var}, 'unescape', #{promises});\n"
      elsif child.is_a?(EJX::Template::HTMLTag)
        child.to_js(var_generator: var_generator, indentation: indentation, append: output_var, namespace: namespace, promises: promises)
      else
        child.to_js(var_generator: var_generator, indentation: indentation, append: output_var, promises: promises)
      end
    end

    js << "#{' '*indentation}__ejx_append(#{output_var}, #{append}, 'unescape', #{promises});\n"
    js
  end
  
end