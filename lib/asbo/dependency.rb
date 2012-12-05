module ASBO
  class Dependency
    attr_reader :package, :version, :build_config, :arch, :abi

    def initialize(package, version, build_config, arch, abi)
      @package, @version, @build_config, @arch, @abi = package, version, build_config, arch, abi
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
