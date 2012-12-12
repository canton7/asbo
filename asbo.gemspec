$LOAD_PATH.unshift(File.dirname(File.expand_path(__FILE__)))
require 'lib/asbo/version'

CamelName = 'ASBO'
bin_name = 'asbo'

Gem::Specification.new do |s|
  s.name = bin_name
  s.version = Kernel.const_get(CamelName)::VERSION
  s.summary = 'Project dependency-management system'
  s.description = "#{CamelName} is a package-based build- and dependency-management system for projects."
  s.authors = ['Antony Male', 'Mark Ferry']
  s.email = ["antony dot male at geemail dot com", "mark at markferry dot net"]
  # s.homepage = 'https://github.com/canton7/asbo'
  s.files = Dir['{bin,lib}/**/*'] + ['README.md']
  s.executables << bin_name

  s.add_dependency 'trollop'
  s.add_dependency 'zip'
  s.add_dependency 'nokogiri'
  s.add_dependency 'sem_version'

  s.required_ruby_version = '>= 1.9.0'
end
