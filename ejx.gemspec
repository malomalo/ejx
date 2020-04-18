require_relative 'lib/ejx/version'

Gem::Specification.new do |s|
  s.name        = "ejx"
  s.version     = EJX::VERSION
  s.licenses    = ['MIT']
  s.summary     = "EJX Template Compiler"
  s.description = <<~TXT
                    Compile EJX (Embedded JavaScript) templates to Javascript
                    with Ruby.
                  TXT

  s.files       = Dir["README.md", "LICENSE", "lib/**/*.{rb,js}"]

  s.add_development_dependency "rake"
  s.add_development_dependency "bundler"
  s.add_development_dependency "minitest"
  s.add_development_dependency "minitest-reporters"

  s.authors     = ["Jonathan Bracy"]
  s.email       = ["jonbracy@gmail.com"]
  s.homepage    = "https://github.com/malomalo/ejx"
end
