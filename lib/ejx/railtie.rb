# frozen_string_literal: true

require "rails/railtie" if defined?(Rails::Railtie)

module EJX
  class Railtie < ::Rails::Railtie
    # Ensure EJX runtime asset directory is on the asset load paths
    initializer "ejx.assets_path", before: "propshaft.assets_middleware" do |app|
      if defined?(::Propshaft)
        app.config.assets.paths << EJX::ASSET_DIR unless app.config.assets.paths.include?(EJX::ASSET_DIR)
      end
    end

    initializer "ejx.importmap", after: "importmap" do |app|
      begin
        require "importmap/map"
      rescue LoadError
        # importmap-rails not present
      end

      if defined?(::Importmap) && defined?(::Importmap::Map)
        require_relative "importmap_map_extensions"
        ::Importmap::Map.prepend(EJX::ImportmapMapExtensions)

        # Pin the EJX runtime so compiled templates can `import 'ejx'`
        if app.respond_to?(:importmap)
          already_pinned = app.importmap.packages.key?("ejx") rescue false
          app.importmap.pin("ejx", to: "ejx.js") unless already_pinned
        end
      end
    end

    initializer "ejx.propshaft" do |app|
      if defined?(::Propshaft)
        # Ensure .ejs/.ejx are treated as JavaScript by Rails' Mime mapping
        Mime::Type.register "text/javascript", :ejs unless Mime::Type.lookup_by_extension(:ejs)
        Mime::Type.register "text/javascript", :ejx unless Mime::Type.lookup_by_extension(:ejx)

        # Register compiler to process EJX/EJS sources when delivering JS
        app.config.assets.compilers << [ "text/javascript", ::Propshaft::Compiler::Ejx ]
      end
    end
  end
end
