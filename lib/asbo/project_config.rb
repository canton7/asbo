require 'yaml'

module ASBO
  class ProjectConfig

    attr_reader :arch, :abi, :project_dir

    def initialize(project_dir, arch, abi)
      @arch, @abi, @project_dir = arch, abi, project_dir
      buildfile = File.join(project_dir, BUILDFILE)
      raise "Can't find buildfile at #{File.expand_path(buildfile)}" unless File.file?(buildfile)
      @config = YAML::load_file(buildfile)
      raise "Invalid buildfile (no package specified)" unless @config && @config.has_key?('package')
    end

    def package
      @config['package']
    end

    def dependencies
      return [] unless @config['dependencies']
      @config['dependencies'].map{ |k,v| Dependency.new(k, *v.split(':', 2), @arch, @abi) }
    end

    def to_dep(build_config, version)
      Dependency.new(package, version, build_config, @arch, @abi)
    end


  end
end
