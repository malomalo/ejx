# frozen_string_literal: true

require "pathname"

module EJX
  module ImportmapMapExtensions
    def find_javascript_files_in_tree(path)
      files = []
      files.concat Dir[path.join("**/*.js{,m}")]
      %w[ejx ejs ejx.html ejs.html html.ejx html.ejs].each do |ext|
        files.concat Dir[path.join("**/*.#{ext}")]
      end
      files.sort!
      files.uniq!
      files.map { |file| Pathname.new(file) }.select(&:file?)
    end

    # Use the default importmap module_path behavior; Propshaft serves
    # these paths with JavaScript content via the EJX compiler.
  end
end
