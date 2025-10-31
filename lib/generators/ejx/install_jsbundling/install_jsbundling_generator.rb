# frozen_string_literal: true

require "rails/generators"
require "json"

module Ejx
  # Invoke with: rails g ejx:install_jsbundling
  class InstallJsbundlingGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :bundler, type: :string, default: "esbuild", desc: "Which jsbundling bundler to integrate with (esbuild only for now)"

    def verify_bundler
      unless options[:bundler] == "esbuild"
        say_status :warning, "Only esbuild is supported right now.", :yellow
      end
    end

    def create_plugin
      template "esbuild-ejx-plugin.js", "esbuild-ejx-plugin.js"
    end

    def create_or_update_esbuild_config
      config_path = Rails.root.join("esbuild.config.mjs")
      if config_path.exist?
        content = File.read(config_path)
        unless content.include?("ejx-plugin") || content.include?("ejxPlugin(")
          append_to_file config_path, <<~JS

            // Injected by ejx: use the EJX plugin to compile .ejs/.ejx
            import ejxPlugin from './esbuild-ejx-plugin.js'
            options.plugins = (options.plugins || []).concat(ejxPlugin())
          JS
        end
      else
        template "esbuild.config.mjs", "esbuild.config.mjs"
      end
    end

    def update_package_json_scripts
      package_json = Rails.root.join("package.json")
      return unless package_json.exist?

      pkg = JSON.parse(File.read(package_json))
      pkg["scripts"] ||= {}

      # Only overwrite scripts if they look like jsbundling-rails defaults
      if pkg["scripts"]["build"]&.match?(/esbuild\s/) || pkg["scripts"]["build"].nil?
        pkg["scripts"]["build"] = "node esbuild.config.mjs"
      end
      if pkg["scripts"]["build:watch"]&.match?(/esbuild\s/) || pkg["scripts"]["build:watch"].nil?
        pkg["scripts"]["build:watch"] = "node esbuild.config.mjs --watch"
      end

      File.write(package_json, JSON.pretty_generate(pkg) + "\n")
    end

    def vendor_ejx_runtime
      require 'ejx'
      dest_dir = Rails.root.join("app/javascript/vendor")
      FileUtils.mkdir_p(dest_dir)
      source_runtime = File.join(::EJX::ASSET_DIR, 'ejx.js')
      contents = File.read(source_runtime)
      create_file dest_dir.join("ejx.js"), contents
    end

    def post_install_message
      say "EJX esbuild integration installed:\n- esbuild-ejx-plugin.js\n- esbuild.config.mjs (created or updated)\n- package.json scripts updated to use the config", :green
    end
  end
end
