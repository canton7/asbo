module ASBO
  class Dependency
    attr_reader :package, :version_constraint, :build_config, :arch, :abi, :dep_of

    def initialize(package, version_constraint, build_config, arch, abi, dep_of=nil)
      @package, @version_constraint, @build_config, @arch, @abi, @dep_of = package, version_constraint, build_config, arch, abi, dep_of
    end

    def is_source?
      @version_constraint == SOURCE_VERSION
    end

    def to_s
      "#{@package} (#{@version_constraint})" 
    end
  end
end
