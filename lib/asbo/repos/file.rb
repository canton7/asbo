require 'fileutils'

module ASBO::Repo
  class File
    include ASBO::Logger

    def initialize(workspace_config, source, package, type, version)
      path = source['path']
      vars = {
        'package' => package,
        'version' => version,
      }
      path = workspace_config.resolve_vars_in_str(path, vars)
      @path = ::File.expand_path(::File.join(workspace_config.workspace, path))
      log.debug "Got path: #{@path}"
    end

    def download
      raise AppError,  "Can't find package source #{@source}" unless ::File.file?(@path)
      @path
    end

    def publish(package, buildfile, overwrite=false)
      log.debug "Publishing #{package} to #{@path}"

      begin
       FileUtils.mkdir_p(@path) unless ::File.directory?(@path)
      rescue SystemCallError => e
        raise ASBO::AppError, "Failed to create dir: #{e.message}"
      end

      exists = ::File.file?(@path)
      raise ASBO::AppError, "File #{@path} already exists. Use the appropriate flag to force overwriting" if exists && !overwrite

      log.debug "Uploading..."
      begin
        FileUtils.cp(file, @path)
      rescue SystemCallError => e
        raise ASBO::AppError, "Failed to publish file #{@path}: #{e.message}"
      end
      log.info "Published #{@path}"
    end
  end
end
