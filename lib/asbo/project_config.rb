require 'yaml'

module ASBO
  class ProjectConfig
    include Logger

    attr_reader :arch, :abi, :project_dir, :build_config, :package

    def initialize(buildfile, arch, abi, build_config, package_name=nil)
      project_dir = File.dirname(buildfile)
      @arch, @abi, @build_config, @project_dir = arch, abi, build_config, project_dir

      raise AppError,  "Can't find buildfile at #{File.expand_path(buildfile)}" unless File.file?(buildfile)
      @config = IniParser.new(buildfile).load
      raise AppError,  "Invalid buildfile (no project specified)" unless @config['project.name']

      @project = @config['project.name']

      # Check the specified package actually exists
      # Packages can be nil, or project.name (if there are no packages), or project-package
      @package_name = package_name
      case package_name
      when nil
        # Use the first package if there's only one
        @package = packages.length == 1 ? packages.first : @project
      when @project
        @package = @project
      else
        raise "Package #{package_name} doesn't exist" if !package_names.include?(package_name)
        @package = "#{@project}-#{package_name}"
      end

      # personal_buildfile = File.join(project_dir, PERSONAL_BUILDFILE)
      # @config.merge!(YAML::load_file(personal_buildfile)) if File.file?(personal_buildfile)
    end

    def package_names
       @config.find_sections(/^package\..*$/).map{ |k,_| k.to_s.sub(/^package\./, '') }
    end

    def packages
      package_names.map{ |x| "#{@project}-#{x}" }
    end

    def package_name=(val)
      # We're passed the package name without the project prefix
      @package_name = val

      if val.nil?
        @package = @project
        return
      end

      raise AppError, "Package #{val} doesn't exist" unless package_names.include?(val)
      @package = "#{@project}-#{val}"
    end

    def package=(val)
      # We're passed the package name with the project prefix
      package = (val == @project) ? nil : val.sub(/^#{@project}-/, '')
    end

    def dependencies
      dep_config = [*@config.get('project.depends', [])]
      dep_config.push(*@config.get("package.#{@package_name}.depends", [])) if @package_name

      our_dep = to_dep(@build_config, nil)

      return [] unless dep_config
      [*dep_config].map do |x|
        package, config, version = x.split(/\s*:\s*/, 3)
        # Allow them to skip the config bit
        if version.nil?
          version, config = config, @build_config
        elsif config.empty?
          config = @build_config
        end
        Dependency.new(package, version, config, @arch, @abi, our_dep)
      end
    end

    def publish_rules
      rules = [*@config.get('project.publish', [])]
      rules.push(*@config.get("package.#{@package}.publish", [])) if @package
      Hash[rules.map{ |x| x.split(/\s*=>\s*/) }]
    end

    def to_dep(build_config, version)
      Dependency.new(@package, version, build_config, @arch, @abi)
    end
  end
end
