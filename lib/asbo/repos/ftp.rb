require 'net/ftp'
require 'uri'

module ASBO::Repo
  class FTP
    include ASBO::Logger

    def initialize(workspace_config, source, package, type, version)
      vars = {
        'package' => package,
        'version' => version,
      }

      source = workspace_config.resolve_config_vars(source, vars, package)
      url = source['url']
      parsed_url = URI::parse(url)
      @user = parsed_url.user || source['username'] || 'anonymous'
      @pass = parsed_url.password || source['password'] || nil
      @host = parsed_url.host
      @package_path = parsed_url.path + ASBO::PACKAGE_EXTENSION 
      @buildfile_path = parsed_url.path + '.' << ASBO::BUILDFILE

      log.debug "Got Host: #{@host}, Path: #{@package_path}, User: #{@user}"
    end

    def download
      file = Tempfile.new([@teamcity_package, ASBO::PACKAGE_EXTENSION])
      file.binmode

      begin
        Net::FTP.open(@host) do |ftp|
          begin
            ftp.login(@user, @pass)
          rescue Net::FTPPermError => e 
            raise ASBO::AppError, "Failed to log in to ftp: #{e.message}"
          end
          ftp.passive = true
          log.debug "Logged in. Now downloading..."
          begin
            ftp.getbinaryfile(@package_path, nil, 1024) do |chunk|
              file.write(chunk)
            end
          rescue Net::FTPPermError => e 
            raise ASBO::AppError, "Failed to fetch file #{@package_path}: #{e.message}"
          end
        end
      ensure
        file.close
      end

      log.debug "Downloaded to #{file.path}"
      file.path
    end

    def publish(package, buildfile, overwrite=false)
      log.debug "Publishing #{@package_path}"
      Net::FTP.open(@host) do |ftp|
        begin
          ftp.login(@user, @pass)
        rescue Net::FTPPermError => e 
          raise ASBO::AppError, "Failed to log in to ftp: #{e.message}"
        end
        log.debug "Logged in."
        ftp.passive = true

        begin
          ftp.chdir(::File.dirname(@package_path))
        rescue Net::FTPPermError => e
          if e.message[0, 3] == '550'
            log.debug "Creating dir: #{::File.dirname(@package_path)}"
            ftp.mkdir(::File.dirname(@package_path))
            ftp.chdir(::File.dirname(@package_path))
          else
            raise ASBO::AppError, "Could not chdir, #{e.message}"
          end
        end

        exists = ftp.size(::File.basename(@package_path)) > 0 rescue false
        raise ASBO::AppError, "File #{@package_path} already exists. Use the appropriate flag to force overwriting" if exists && !overwrite

        [package, buildfile].zip([@package_path, @buildfile_path]).each do |file, path|
          log.debug "Uploading #{file}..."

          begin
            ftp.putbinaryfile(file, ::File.basename(path))
          rescue Net::FTPPermError => e 
            raise ASBO::AppError, "Filed to upload file #{path}: #{e.message}"
          end
          log.info "Uploaded #{path}"
        end
      end
    end
  end
end
