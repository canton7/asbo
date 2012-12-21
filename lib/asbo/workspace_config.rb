module ASBO
  class WorkspaceConfig
    include Logger

    VARIABLE_FIND_REGEX = /(?<!\\)\$([a-zA-Z][0-9a-zA-Z_]*)/

    attr_reader :workspace

    def initialize(start_dir)
      @workspace = find_workspace(start_dir)
      sources_config = File.join(@workspace, SOURCES_CONFIG)
      raise AppError,  "Unable to find sources config file (should be at #{sources_config})" unless File.file?(sources_config)
      @source_config = YAML::load_file(sources_config)
    end

    def cache_dir
      File.join(@workspace, CACHE_DIR)
    end

    # type can be e.g. 'release' or 'latest'
    def package_source(package, type)
      # First look in package section, then in main bit. In each, first check type, then 'release'
      source = {}

      if @source_config.has_key?(package)
        source = @source_config[package][type].merge(source) if @source_config[package].has_key?(type)
        source = @source_config[package]['release'].merge(source) if @source_config[package].has_key?('release')
      end
      
      source = @source_config[type].merge(source) if @source_config.has_key?(type)
      source = @source_config['release'].merge(source) if @source_config.has_key?('release')

      raise AppError,  "Could not find source for package #{package}, type #{type}" if source == {}

      source
    end

    def package_publish_source(package, type)
      # Start with the package source, then try the publish section
      source = package_source(package, type)

      source.merge!(@source_config["publish_#{type}"]) if @source_config.has_key?("publish_#{type}")
      source
    end

    def resolve_vars_in_str(str, var_definitions)
      begin
        new_str, str = str.gsub(VARIABLE_FIND_REGEX){ var_definitions[$1] || "$#{$1}" }, new_str
      end while str =~ VARIABLE_FIND_REGEX && str != new_str
      new_str
    end

    def resolve_config_vars(value, var_definitions={}, section=nil)
      if value.is_a?(Hash)
        value.each do |k,v|
          value[k] = resolve_config_vars(v, var_definitions, section)
        end
        return value
      end

      var_definitions = find_vars(@source_config, section).merge(var_definitions)

      # Make sure all of the definitions are resolved
      var_definitions.each do |k,v|
        var_definitions[k] = resolve_vars_in_str(v, var_definitions) if v =~ VARIABLE_FIND_REGEX
      end
      
      value = resolve_vars_in_str(value, var_definitions)
      value
    end

    def find_vars(config, section=nil)
      # Look in the base first, and then section
      vars = {}
      vars = @source_config.select{ |k,v| k.start_with?('$') }.merge(vars)
      vars = @source_config[section].select{ |k,v| k.start_with?('$') }.merge(vars) if section && @source_config[section]
      Hash[vars.map{ |k,v| [k[1..-1], v] }]
    end

    def parse_source_variables(source, string)
      # Convert the source into regex which we can use to match against the string
      # Find the positions of all variable names
      variables = source.scan(VARIABLE_FIND_REGEX).flatten
      r = Regexp.new('\A' << source.gsub(VARIABLE_FIND_REGEX, '(.+?)') << '\Z')
      match = r.match(string)
      if match.nil?
        # No match. Return nil
        return nil
      end
      captures = variables.zip(match.captures)
      # Collect into a hash of variable => values
      captures.inject(Hash.new{ |h,k| h[k] = []}){ |s,(k,v)| s[k] << v; s }
    end

    def find_workspace(start_dir)
      folder = File.expand_path(start_dir)
      until File.exists?(File.join(folder, WORKSPACE_INDICATOR)) do
        folder, old = File.expand_path(File.join(folder, '..')), folder
        raise AppError,  "Unable to find workspace directory, starting at #{start_dir} (looking for #{WORKSPACE_INDICATOR})" if folder == old
      end
      folder
    end
  end
end
