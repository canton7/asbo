require 'zip/zip'

module ASBO
  class PackageManager
    include Logger

    PUBLISH_RULES = {
      'inc/.' => 'inc',
      'bin/.' => 'bin',
      'lib/.' => 'lib',
    }

    attr_reader :workspace_config, :project_config

    def initialize(workspace_config, project_config)
      @workspace_config, @project_config = workspace_config, project_config
    end

    def resolve_deps_level(packages, possible_packages=nil)
      deps = []
      packages.each{ |p| deps.push(*p.dependencies) }
      # package -> array of versions
      possible_packages ||= {}

      deps.select!{ |x| !possible_packages.map{ |_,y| y[:dependency] }.include?(x) }
      # Now we have a list of packages and constraints. Let's get a list of available versions
      p deps
      deps.each do |dep|
        puts "LOOKING AT #{dep}"
        # If the key exists already, it means someone else has a dependency on that package
        # and has already populated the array with the versions they accept
        # In this case, just filter it. Otherwise populate it with all versions and then filter it
        unless possible_packages.has_key?(dep.package)
          # See what versions exist..
          repo = Repo.factory(@workspace_config, dep.package, nil, 'release')
          versions = repo.list_versions.select do |x|
            unless SemVersion.valid?(x)
              log.warn "Version #{x} for package #{dep.package} is not a valid semantic version. Ignoring"
              false
            else
              true
            end
          end
          possible_packages[dep.package] ||= {:dependency => dep, :versions => []}
          possible_packages[dep.package][:versions].push(*versions.map{ |x| SemVersion.new(x) })
        end

        # OK, so now we have a list of versions. Filter them!
        possible_packages[dep.package][:versions].select!{ |x| x.satisfies?(dep.version_constraint) }
      end

      p possible_packages

      # TODO raise if we fail the dep checks here (no package meets requirements)

      # Filter possible_packages to ones that are new this round. We don't want to inspect
      # them twice.
      # Turn that into [[{:package => a, :version => 1}, { ... }], [{ ... }]]
      # puts "Filtered: "
      # p possible_packages.select{ |k,v| deps.include?(v[:dependency]) }
      package_list = possible_packages.map do |k,v|
        v[:versions].map{ |v2| {:dependency => v[:dependency], :version => v2} }
      end

      # p package_list

      # If it's empty (or contains one element?), get out
      return possible_packages if package_list.empty?

      # Get all combinations of all versions
      # This leaves them sorted in a sensible order 
      package_combinations = package_list[0].product(*package_list[1..-1])

      # For each combination, try and resolve that further
      # If a given resolution fails, try the next
      package_combinations.each do |combination|
        # We have 
        # TODO better deep clone
        poss_packages = Marshal.load(Marshal.dump(possible_packages))
        log.debug "Looking at combination: #{combination}"
        # Does this combination work together? Try and resolve_deps on it
        projs = combination.map{ |x| download_buildfile(x[:dependency], x[:version]) }
        p projs.map{ |p| p.package }

        resolve_deps_level(projs, poss_packages)
      end

      possible_packages


      # # Now we have a hash of deps => allowed dep versions (which exist)
      # # For each package, start with the hightest dep try and recursively resolve
      # # If that fails, move onto the next...
      # possible_packages.each do |dep, versions|
      #   versions.sort!
      #   log.debug "The following #{dep.package} versions are suitable: #{versions.join(', ')}"
      #   versions.each do |version|
      #     log.debug "Trying #{version}"
      #     # TODO support source dependencies
      #     project_config = download_buildfile(dep, version)

      #     p project_config.dependencies
      #   end

      # end

      # possible_packages
    end

    def download_dependencies(project_config=nil)
      project_config ||= @project_config
      # For test
      resolve_deps_level([project_config])

      # project_config ||= @project_config
      # log.info "Resolving dependencies for #{project_config.package}..."
      # deps = project_config.dependencies
      # log.debug "No dependencies found" if deps.empty?
      # deps.each do |dep|
      #   log.debug "Processing dependency #{dep}"
      #   if dep.is_source?
      #     process_source_dep(dep)
      #   else
      #     process_package_dep(dep, )
      #   end
      # end
    end

    def dep_downloaded?(dep)
      File.directory?(dependency_path(dep))
    end

    def dependency_path(dep)
      package_path(dep.package, dep.version)
    end

    def package_path(package, version)
      File.join(@workspace_config.cache_dir, "#{package}-#{version}")
    end

    def buildfile_path(package, version)
      package_path(package, version) << ".#{BUILDFILE}"
    end

    def headers_path(dep)
      File.join(dependency_path(dep), 'inc')
    end

    def artifacts_path(dep)
      File.join(dependency_path(dep), 'bin', "#{dep.arch}-#{dep.abi}-#{dep.build_config}")
    end

    def binaries_path(dep)
      File.join(dependency_path(dep), 'bin')
    end

    def lib_path(dep)
      File.join(dependency_path(dep), 'lib')
    end

    def all_dependencies
      r = []
      @project_config.dependencies.each do |dep|
        r.push(*recursive_dependencies(dep))
      end

      check_dependency_version_conflcits(r)

      r
    end

    def recursive_dependencies(dep)
      # Return all of this dependencies' dependecies
      unless File.file?(File.join(dependency_path(dep), BUILDFILE))
        log.warn "Unable to find buildfile for #{dep}"
        return [dep]
      end
      proj_conf = ProjectConfig.new(dependency_path(dep), dep.arch, dep.abi, @project_config.build_config)
      proj_conf.package = dep.package
      deps = proj_conf.dependencies
      r = [dep]
      deps.each do |d|
        r.push(*recursive_dependencies(d))
      end
      r
    end

    def check_dependency_version_conflcits(deps)
      types = deps.inject(Hash.new{ |h,k| h[k] = []}){ |s,d| s[d.package] << d; s }
      types.each do |type, deps|
        raise "BALH" unless deps.map{ |x| x.version }.uniq.length == 1
      end
    end

    def cache_project(version)
      src = @project_config.project_dir
      dest = package_path(@project_config.package, version)

      log.info "Caching #{@project_config.package} to #{dest}"
      # TODO tell them how to nuke this, when we implement it
      log.warn "Overwriting previously-cached copy of version #{version}" if File.directory?(dest) && version != SOURCE_VERSION
      FileUtils.rm_rf(dest)

      package_project(src, dest)
    end

    # dest should point to dir in which to put things
    def package_project(source, dest)
      FileUtils.mkdir_p(dest)
      FileUtils.cp(File.join(source, BUILDFILE), File.join(dest, BUILDFILE))
      PACKAGE_FILES.each do |file|
        cp_if_exists(File.join(source, file), dest)
      end
      rules = @project_config.publish_rules.empty? ? PUBLISH_RULES : @project_config.publish_rules

      rules.each do |from, to|
        log.debug "Processing rule #{from} => #{to}"
        cp_if_exists(File.join(source, from), File.join(dest, to))
      end
    end

    def package_to_zip(source, output=nil)
      zip = output ? output : File.join(Dir.mktmpdir, 'packaged.zip')
      dir = File.dirname(zip)
      # TODO this could be done better
      package_project(source, dir)
      log.debug "Creating zip: #{zip}"
      Dir.chdir(dir) do 
        Zip::ZipFile.open(zip, Zip::ZipFile::CREATE) do |zipfile|
          Dir['**/*'].each do |file|
            zipfile.add(file, file)
          end
        end
      end

      zip
    end

    def publish_project(source, version, overwrite)
      repo = Repo.factory(@workspace_config, @project_config.package, version, 'release', :publish)
      raise AppError, "Repo #{repo} doesn't know how to publish packages" unless repo.respond_to?(:publish)
      log.debug "Publishing buildfile"
      buildfile = File.join(source, ASBO::BUILDFILE)
      zip = package_to_zip(source)
      repo.publish(zip, buildfile, overwrite)
    end

    def clobber
      log.info "Clobbering cache dir. This could take a while..."
      FileUtils.rm_rf(@workspace_config.cache_dir)
    end

    private

    def process_source_dep(dep)
      if dep_downloaded?(dep)
        log.debug "Source dependency #{dep} found"
      else
        raise AppError,  "#{@project_config.package} specifies #{dep} as a dependency. This is a source dependency, so you need to build it"
      end
    end

    def process_package_dep(dep, version)
      if dep_downloaded?(dep)
        log.debug "Package dependency #{dep} is already downloaded"
      else
        download_dep(dep, version)
      end
    end

    def download_buildfile(dep, version)
      buildfile_path = buildfile_path(dep.package, version)
      if File.file?(buildfile_path)
        log.debug "Buildfile for #{dep.package}-#{version} already downloaded"
      else
        log.info "Downloading buildfile for #{dep.package}-#{version}"
        repo = Repo.factory(@workspace_config, dep.package, version, 'release')
        file = repo.download_buildfile
        FileUtils.mkdir_p(File.dirname(buildfile_path))
        FileUtils.mv(file, buildfile_path)
      end
      pc = ProjectConfig.new(buildfile_path, dep.arch, dep.abi, @project_config.build_config)
      pc.package = dep.package
      pc
    end

    def download_dep(dep, version)
      log.info "Downloading #{dep}"
      repo = Repo.factory(@workspace_config, dep.package, version, 'release')
      file = repo.download
      log.info "Extracting #{dep}"
      extract_package(file, dep)
      # Now get recursive deps, if and only if the buildifle exists
      # We warn about it not existing when we look at recursive dependencies in a bit
      if File.file?(File.join(dependency_path(dep), BUILDFILE))
        p = ProjectConfig.new(File.join(dependency_path(dep), BUILDFILE), dep.arch, dep.abi, @project_config.build_config)
        p.package = dep.package
        download_dependencies()
      end
    end

    def extract_package(path, dep)
      dest = dependency_path(dep)
      log.debug "Extracting #{path} to #{dest}"
      Zip::ZipFile.open(path) do |zf|
        zf.each do |e|
          file_dest = File.join(dest, e.name)
          FileUtils.mkdir_p(File.dirname(file_dest))
           zf.extract(e.name, file_dest)
        end
      end
    end

    def cp_if_exists(from, to)
      FileUtils.mkdir_p(to)

      from_glob = Dir.glob(from)
      return if from_glob.empty?

      log.debug "Copying #{from} to #{to}"
      FileUtils.cp_r(from_glob, to)
    end
  end
end
