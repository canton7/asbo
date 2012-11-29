module ASBO
  class BuildManager
    include Logger

    attr_accessor :verbose

    def initialize(arch, abi, build_config, compiler, project_dir=nil)
      project_dir ||= Dir.getwd
      @arch, @abi, @build_config, @compiler, @project_dir = arch, abi, build_config, compiler, project_dir
      @project_config = ProjectConfig.new(project_dir, arch, abi, build_config)
      @workspace_config = WorkspaceConfig.new(project_dir)
      @verbose = false
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

    def pre_build(output_opts)
      log.info "Performing pre-build action"
      download_deps
      
      output(output_opts[:bin], compiler.bin_paths_str) if output_opts[:bin]
      output(output_opts[:include], compiler.include_paths_str) if output_opts[:include]
    end

    def post_build
      log.info "Performing post-build action"
      version = ENV['VERSION'] || SOURCE_VERSION
      package_manager.cache_project(version)
    end

    def publish(version, overwrite=false)
      log.info "Performing publish action, version #{version}"
      file = package
      package_manager.publish_zip(file, version, overwrite)
    end

    def package(output=nil)
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
        File.open(dest, 'w'){ |f| f.write(value) }
      end
    end
  end
end
