CamelName = 'Asbo'
bin_name = 'asbo'

Gem::Specification.new do |s|
  s.name = bin_name
  s.version = '0.0.0'
  s.summary = CamelName
  s.description = '#{CamelName} is a package-based build- and dependency-management system for projects.'
  s.authors = ["Antony Male", "Mark Ferry"]
#  s.email = [""]
#  s.homepage = 
#  s.rubyforge_project = bin_name
  s.files = Dir['{bin,lib}/**/*'] + ['README.md']
  s.executables << bin_name
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.add_dependency 'trollop'
  s.add_dependency 'zip'
end
