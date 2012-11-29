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
      @path = ::File.expand_path(::File.join(workspace_config.workspace, path)) << '.zip'
      log.debug "Got path: #{@path}"
    end

    def download
      raise AppError,  "Can't find package source #{@source}" unless ::File.file?(@path)
      @path
    end

    def publish(file, overwrite=false)
      log.debug "Publishing #{@path}"

      begin
        FileUtils.cd(::File.dirname(@path))
      rescue SystemCallError => e
        if e == Errno::ENOENT
          log.debug "Creating dir: #{::File.dirname(@path)}"
          FileUtils.mkdir_p(::File.dirname(@path))
          FileUtils.cd(::File.dirname(@path))
        else
          raise ASBO::AppError, "Could not chdir, #{e.message}"
        end
      end

      exists = File.file?(::File.basename(@path)) rescue false
      raise ASBO::AppError, "File #{@path} already exists. Use the appropriate flag to force overwriting" if exists && !overwrite

      log.debug "Uploading..."
      begin
        FileUtils.cp(file, ::File.basename(@path))
      rescue SystemCallError => e
        raise ASBO::AppError, "Failed to upload file #{@path}: #{e.message}"
      end
      log.info "Uploaded #{@path}"
    end
  end
end
