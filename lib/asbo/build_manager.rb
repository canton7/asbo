module ASBO
  class BuildManager
    include Logger

    attr_accessor :verbose

    def initialize(arch, abi, build_config, compiler, package=nil, project_dir=nil)
      project_dir ||= Dir.getwd
      # for some reason, Dir.glob (later on) doesn't like backslashes
      project_dir = project_dir.gsub('\\', '/')
      @arch, @abi, @build_config, @compiler, @package, @project_dir = arch, abi, build_config, compiler, package, project_dir
      @project_config = ProjectConfig.new(File.join(project_dir, BUILDFILE), arch, abi, build_config, package)
      @workspace_config = WorkspaceConfig.new(project_dir)
      @verbose = false
      log.debug "Using project directory #{@project_dir}"
    end

    def package_manager
      @pacman ||= PackageManager.new(@workspace_config, @project_config)
      @pacman
    end

    def download_deps
      package_manager.download_dependencies
    end

    def compiler
      Compiler::factory(@compiler, package_manager)
    end

    def pre_build(output_opts={})
      if !@package && @project_config.packages.count > 1
        raise AppError, "You must provide a package to pre-build, as this project has multiple packages" 
      end
      log.info "Performing pre-build action"
      download_deps
      output(output_opts[:bin], compiler.bin_paths_str) if output_opts[:bin]
      output(output_opts[:include], compiler.include_paths_str) if output_opts[:include]

      self
    end

    def post_build
       if !@package && @project_config.packages.count > 1
        raise AppError, "You must provide a package to post-build, as this project has multiple packages" 
      end
      log.info "Performing post-build action for package #{@project_config.package}"
      version = ENV['VERSION'] || SOURCE_VERSION
      package_manager.cache_project(version)

      self
    end

    def publish(version, overwrite=false)
      # If there are packages, use them, otherwise use default
      if @package
        packages = [@package]
      else
        packages = @project_config.package_names.empty? ? [nil] : @project_config.package_names
      end
      # packages = @package ? [@package] : @project_config.packages
      packages.each do |package|
        @project_config.package_name = package
        package_str = package ? " #{package}" : ''
        log.info "Performing publish action for package#{package_str}, version #{version}"
        package_manager.publish_project(@project_dir, version, overwrite)
      end
    end

    # If package is nil, package the default package, otherwise package the specified one
    def package(output=nil, package=nil)
      # Allow overwriting...
      @project_config.package_name = package
      package_manager.package_to_zip(@project_dir, output)
    end

    def clobber
      package_manager.clobber
    end

    private

    def output(dest, value)
      if dest.empty? || dest == 'stdout'
        puts value
      else
        File.open(File.join(@project_dir, dest), 'w'){ |f| f.write(value) }
      end
    end
  end
end
