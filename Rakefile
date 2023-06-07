require 'bundler/setup'
require "bundler/gem_tasks"
require "rake/testtask"

task default: :test

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList[ARGV[1] ? ARGV[1] : 'test/**/*_test.rb']
end
