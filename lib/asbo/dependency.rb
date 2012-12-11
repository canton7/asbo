module ASBO
  class Dependency
    attr_reader :package, :version, :build_config, :arch, :abi, :dep_of

    def initialize(package, version, build_config, arch, abi, dep_of=nil)
      @package, @version, @build_config, @arch, @abi, @dep_of = package, version, build_config, arch, abi, dep_of
    end

    def is_source?
      @version == SOURCE_VERSION
    end

    def is_latest?
      @version == LATEST_VERSION
    end

    def to_s
      "#{@package}-#{@version}" 
    end
  end
end
