require_relative 'repos/file'
require_relative 'repos/teamcity'

module ASBO
  module Repo
    def self.factory(workspace_config, package, type, version)
      source = workspace_config.package_source(package, type)

      driver = source['driver']
      raise "You must specify the driver in sources.yml" unless driver

      case driver
      when 'file'
        Repo::File.new(workspace_config, source, package, type, version)
      when 'teamcity'
        Repo::TeamCity.new(workspace_config, source, package, type, version)
      else
        raise "Unknown driver '#{driver}' for source #{source}"
      end
    end
  end
end
