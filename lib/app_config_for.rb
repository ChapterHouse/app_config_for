# frozen_string_literal: true

require_relative "app_config_for/version"
require_relative "app_config_for/errors"

require 'active_support/gem_version'
if ActiveSupport.gem_version >= Gem::Version.new('6.1.4')
  require 'active_support/environment_inquirer'
  require 'active_support/configuration_file'
else
  require_relative 'app_config_for/legacy_support'
end

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/ordered_options'
require 'active_support/core_ext/object/try'
require 'active_support/backtrace_cleaner'

# {<img src="https://badge.fury.io/rb/app_config_for.svg" alt="Gem Version" />}[https://badge.fury.io/rb/app_config_for]
# 
# Ruby gem providing Rails::Application#config_for style capabilities for non-rails applications, gems, and rails engines.  
# It respects RAILS_ENV and RACK_ENV while providing additional capabilities beyond Rails::Application#config_for.
# 
# = Usage
# Typical usage will be done by extension but inclusion is also supported.
# 
# Presume a typical rails database config at ./config/database.yml
# 
# One environment variable ('MY_APP_ENV', 'RAILS_ENV', or 'RACK_ENV') is set to 'development' or all are non existent.
#
# ==== ./config/sample_app.yml
#  default: &default
#    site: <%= ENV.fetch("MY_APP_SITE", 'www.slackware.com') %>
#    password: Slackware#1!
# 
#  development:
#  <<: *default
#  username: Linux
# 
#  test:
#  <<: *default
#  username: TestingWith
# 
#  production:
#  <<: *default
#  username: DefinitelyUsing
# 
#  shared:
#  color: 'Blue'
# 
# === sample_application.rb
#  require 'app_config_for'
# 
#  module Sample
#    class App
#      extend AppConfigFor
#      def info
#        puts "Current environment is #{App.env}"
#
#        # Access the configuration in various ways depending on need/preference.
#        puts "Remote Host: #{App.site}"
#        puts "Username:    #{App.configured.username}"
#        puts "Password:    #{App.config_for(App).password}"
#        puts "Domain:      #{self.class.config_for(:app)[:domain]}"
# 
#        # Access a different config
#        if App.config_file?(:database)
#          adapter_name = App.config_for(:database).adapter
#          puts "Rails is using the #{adapter_name} adapter."
#        end
#      end
#    end
#  end
# 
module AppConfigFor
  # Types of hierarchical traversal used to determine the runtime environment.
  # * +:none+ - No inheritance active
  # * +:namespace+ - Inheritance by lexical namespace
  # * +:class+ - Inheritance by class hierarchy
  # * +:namespace_class+ - Namespace inheritance combined with class inheritance
  # * +:class_namespace+ - Class inheritance combined with namespace inheritance
  EnvInheritanceStyles = [:none, :namespace, :class, :namespace_class, :class_namespace]

  # AppConfigFor can be included instead of extended. If this occurs, instances of the class will have their
  # own list of prefixes. The default class prefix will be automatically added to the list.
  def initialize(*args)
    add_env_prefix
    super
  end

  # Add multiple additional directories to be used when searching for the config file.
  # Any duplicates will be ignored.
  # @param additional_directories [Array<#to_s>] additional directories to add
  # @param at_beginning [Boolean] where to insert the new directories with respect to existing prefixes
  #   * +true+ - Add to the beginning of the list.
  #   * +false+ - Add to the end of the list.
  # @return [Array<Pathname>] updated array of additional config directories
  # @see #additional_config_directories Additional config directories
  # @see #config_directories All config directories
  def add_config_directories(*additional_directories, at_beginning: true)
    additional_directories = additional_directories.flatten.map { |d| Pathname.new(d.to_s) }
    directories = additional_config_directories(false).send(at_beginning ? :unshift : :push, additional_directories)
    directories.flatten!
    directories.uniq!
    directories.dup
  end

  # Add an single additional directory to be used when searching for the config file.
  # Any duplicates will be ignored.
  # @param additional_directory [#to_s] additional directory to add
  # @param at_beginning [Boolean] where to insert the new directory with respect to existing prefixes
  #   * +true+ - Add to the beginning of the list.
  #   * +false+ - Add to the end of the list.
  # @return [Array<Pathname>] updated array of additional config directories
  # @see #additional_config_directories Additional config directories
  # @see #config_directories All config directories
  def add_config_directory(additional_directory, at_beginning = true)
    add_config_directories additional_directory, at_beginning: at_beginning
  end

  # Add an additional base name to be used when locating the config file.
  # @param config_name [Object] Object to extract a config name from.
  # @param at_beginning [Boolean] where to insert the new config name with respect to existing names.
  #   * +true+ - Add to the beginning of the list.
  #   * +false+ - Add to the end of the list.
  # @return [Array<Object>] current config names
  # @see yml_name_from How the name of the yml file is determined
  def add_config_name(config_name, at_beginning = true)
    add_config_names config_name, at_beginning: at_beginning
  end

  # Add multiple additional base names to be used when locating the config file.
  # @param config_names [Array<Object>] Array of objects to extract a config name from.
  # @param at_beginning [Boolean] where to insert the new config names with respect to existing names.
  #   * +true+ - Add to the beginning of the list.
  #   * +false+ - Add to the end of the list.
  # @return [Array<Object>] current config names
  # @see yml_name_from How the name of the yml file is determined
  def add_config_names(*config_names, at_beginning: true)
    names = config_names(false).send(at_beginning ? :unshift : :push, config_names)
    names.flatten!
    names.uniq!
    names.dup
  end

  # Add an additional environmental prefix to be used when determining current environment.
  # @param prefix [Symbol, Object] Prefix to add.  
  #  +nil+ is treated as +self+   
  #  Non symbols are converted via {.prefix_from AppConfigFor.prefix_from}.  
  # @param at_beginning [Boolean] where to insert the new prefix with respect to existing prefixes
  #   * +true+ - Add to the beginning of the list.
  #   * +false+ - Add to the end of the list.
  # @return [Array<Symbol>] Current prefixes (without inheritance)
  # @see #env_prefixes Current prefixes
  def add_env_prefix(prefix = nil, at_beginning = true)
    env_prefixes(false, false).send(at_beginning ? :unshift : :push, AppConfigFor.prefix_from(prefix || self)).uniq!
    env_prefixes(false)
  end

  # Directories to be checked in addition to the defaults when searching for the config file.
  # @param dup [Boolean] Return a duplicated array to prevent accidental side effects
  # @return [Array<Pathname>]
  # @see #add_config_directory Adding config directories
  # @see #config_directories All config directories
  def additional_config_directories(dup = true)
    @additional_config_directories ||= []
    dup ? @additional_config_directories.dup : @additional_config_directories
  end

  # Clear all additional config directories and set to the directory given.
  # @param directory [#to_s] additional directory to use
  # @return [Array<Pathname>] updated array of additional config directories
  # @see #additional_config_directories Additional config directories
  # @see #config_directories All config directories
  def config_directory=(directory)
    additional_config_directories(false).clear
    add_config_directory(directory)
  end
  alias_method :config_directories=, :config_directory=

  # All directories that will be used when searching for the config file. Search order is as follows:
  # 1. Rails configuration directories if Rails is present.
  # 2. Engine configuration directories if extended by an engine.
  # 3. Additional configuration directories.
  # 4. ./config within the current working directory.
  # All paths are expanded at time of call.
  # @return [Array<Pathname>] directories in the order they will be searched.
  # @see #add_config_directory Adding config directories
  def config_directories
    directories = ['Rails'.safe_constantize&.application&.paths, try(:paths)].compact.map { |root| root["config"].existent.first }.compact
    directories.concat additional_config_directories
    directories.push(Pathname.getwd + 'config')
    directories.map { |directory| Pathname.new(directory).expand_path }.uniq
  end

  # Configuration file that will be used.
  # This is the first file from {#config_files} that exists or +nil+ if none exists.
  # @param name [Symbol, Object] Name of the config to load.  
  #  Conversion to a file name will occur using {.yml_name_from AppConfigFor.yml_name_from}.  
  #  If name is +nil+ {#config_names} will be used.
  # @param fallback [Symbol, Object] If not +nil+, attempt to load a fallback configuration if the requested one cannot be found.  
  # @return [Pathname, nil]
  def config_file(name = nil, fallback = nil)
    unless name.is_a?(Pathname)
      config_files(name).find(&:exist?)
    else
      name.exist? ? name.expand_path : nil
    end.yield_self { |file| file || fallback && config_file(fallback) }
  end

  # The list of potential config files that will be searched for and the order in which they will be searched.
  # @param name [Symbol, Object] Name of the config to load.  
  #  Conversion to a file name will occur using {.yml_name_from AppConfigFor.yml_name_from}.  
  #  If name is +nil+, {#config_names} will be used.  
  #  If name is object that responds to +config_files+, it will be called instead.
  # @return [Array<Pathname>]
  def config_files(name = nil)
    if name.respond_to?(:config_files) && name != self
      name.config_files
    else
      names = (name && name != self && Array(name) || config_names).map { |name| AppConfigFor.yml_name_from(name) }
      config_directories.map { |directory| names.map { |name| directory + name } }.flatten
    end
  end

  # Does a config file exit?
  # @param name [Symbol, Object] Name of the config to load.  
  #  Conversion to a file name will occur using {.yml_name_from AppConfigFor.yml_name_from}.  
  #  If name is +nil+ {#config_names} will be used.
  # @param fallback [Symbol, Object] If not +nil+, attempt to load a fallback configuration if the requested one cannot be found.  
  # @return [Boolean]
  def config_file?(name = nil, fallback = nil)
    !config_file(name, fallback).blank?
  end

  # Configuration settings for the current environment.
  # Shared sections in the yml config file are automatically merged into the returned configuration.
  # @param name [Symbol, Object] Name of the config to load.  
  #  Conversion to a file name will occur using {.yml_name_from AppConfigFor.yml_name_from}.  
  #  If name is +nil+ {#config_names} will be used.
  # @param env [Symbol, String] name of environment to use. +nil+ will use the current environment settings from {#env}
  # @param fallback [Symbol, Object] If not +nil+, attempt to load a fallback configuration if the requested one cannot be found.  
  # @return [ActiveSupport::OrderedOptions]
  # @raise ConfigNotFound - No configuration file could be located.
  # @raise LoadError - A configuration file was found but could not be properly read.
  # @see yml_name_from How the name of the yml file is determined
  # @see #env The current runtime environment
  # @example
  #   config_for(:my_app)              # Load my_app.yml and extract the section relative to the current environment.
  #   config_for(:my_app).log_level    # Get the configured logging level from my_app.yml for the current environment.
  #   config_for("MyApp", env: 'test') # Load my_app.yml and extract the 'test' section.
  #
  #   module Other
  #     class App
  #     end
  #   end
  #   # Load other_app.yml and extract the 'production' section.
  #   # Notice that Other::App does not need to extend AppConfigFor
  #   config_for(Other::App, env: :production)
  def config_for(name, env: nil, fallback: nil)
    config, shared = config_options(name, fallback).fetch_values((env || self.env).to_sym, :shared) { nil }
    config ||= shared

    if config.is_a?(Hash)
      config = shared.deep_merge(config) if shared.is_a?(Hash)
      config = ActiveSupport::OrderedOptions.new.update(config)
    end

    config
  end

  # Clear all config names and set to the name given.
  # Set the base name of the config file to use.
  # @param new_config_name [Object] Any object. Actual name will be determined using {.yml_name_from AppConfigFor.yml_name_for}
  # @return [Array<Object>] current config names
  # @see yml_name_from How the name of the yml file is determined
  def config_name=(new_config_name)
    config_names(false).clear
    add_config_names(new_config_name)
  end
  alias_method :config_names=, :config_name=

  # Base names of the configuration file.
  # Defaults to: +[self]+
  def config_names(dup = true)
    @config_names ||= [self]
    dup ? @config_names.dup : @config_names
  end

  # Configuration for all environments parsed from the {#config_file}.
  # @param name [Symbol, Object] Name of the config to load.  
  #  Conversion to a file name will occur using {.yml_name_from AppConfigFor.yml_name_from}.  
  #  If name is +nil+ {#config_names} will be used.
  # @param fallback [Symbol, Object] If not +nil+, attempt to load a fallback configuration if the requested one cannot be found.  
  # @return [Hash]
  # @raise ConfigNotFound - No configuration file could be located.
  # @raise LoadError - A configuration file was found but could not be properly read.
  def config_options(name = nil, fallback = nil)
    file = config_file(name, fallback).to_s
    ActiveSupport::ConfigurationFile.parse(file).deep_symbolize_keys
  rescue SystemCallError => exception
    locations = name.is_a?(Pathname) ? Array(name) : config_files(name)
    locations += config_files(fallback) if fallback
    raise ConfigNotFound.new(locations, exception)
  rescue => exception
    raise file ? LoadError.new(file, exception) : exception
  end

  # Convenience method for {config_for}(+self+). Caches the result for faster access.
  # @param reload [Boolean] Update the cached config by rereading the configuration file.
  # @return [ActiveSupport::OrderedOptions]
  # @raise ConfigNotFound - No configuration file could be located.
  # @raise LoadError - A configuration file was found but could not be properly read.
  # @example
  #   module Sample
  #     class App
  #       extend AppConfigFor
  #       @@logger = Logger.new($stdout, level: configured.level)
  #     end
  #   end
  #   Sample::App.configured.url    # Get the configured url from my_app.yml for the current environment
  # @see #method_missing Accessing configuration values directly from the extending class/module
  def configured(reload = false)
    if reload || !@configured
      # @disable_local_missing = true # Disable local method missing to prevent recursion
      @configured = config_for(nil, env: env(reload))
      # @disable_local_missing = false # Reenable local method missing since no exception occurred.
    end
    @configured
  end

  # Convenience method for {configured}(+true+).
  # @return [ActiveSupport::OrderedOptions]
  # @raise ConfigNotFound - No configuration file could be located.
  # @raise LoadError - A configuration file was found but could not be properly read.
  # @example
  #   module Sample
  #     class App
  #       extend AppConfigFor
  #       mattr_accessor :logger, default: Logger.new($stdout)
  #       logger.level = configured.log_level
  #     end
  #   end
  #   # Switch to production
  #   ENV['SAMPLE_APP_ENV'] = 'production'
  #   # Update the log level with the production values
  #   Sample::App.logger.level = Sample::App.configured!.log_level
  def configured!
    configured(true)
  end

  # Check for the existence of a configuration setting. Handles exceptions and recursion.
  # @param key [#to_s] Key to check for
  # @return [Boolean]
  #   * +true+ - Configuration has the key
  #   * +false+ - If one of the following: 
  #     1. Configuration does not have the key
  #     2. Called recursively while retrieving the configuration
  #     3. An exception is raised while retrieving the configuration
  # @note This is primarily used internally during {#respond_to_missing?} and {#method_missing} calls.
  def configured?(key)
    if @disable_local_missing
      false
    else
      @disable_local_missing = true
      begin
        configured.has_key?(key.to_s.to_sym)
      rescue Exception # One of the few times you ever want to catch this exception and not reraise it.
        false
      ensure
        @disable_local_missing = false
      end
    end
  end

  # Returns the current runtime environment. Caches the result.
  # @param reload [Boolean] Update the cached env by requerying the environment
  # @return [ActiveSupport::EnvironmentInquirer]
  # @example
  #   module Sample
  #     extend AppConfigFor
  #   end
  #   Sample.env              # => 'development'
  #   Sample.env.development? # => true
  #   Sample.env.production?  # => false
  def env(reload = false)
    @env = ActiveSupport::EnvironmentInquirer.new(env_name) if reload || @env.nil?
    @env
  end

  # Convenience method for {env}(+true+).
  # @return [ActiveSupport::EnvironmentInquirer]
  # @example
  #   module Sample
  #     extend AppConfigFor
  #   end
  #   Sample.env              # => 'development'
  #   Sample.env.development? # => true
  #   Sample.env.production?  # => false
  #   # Switch to production
  #   ENV['SAMPLE_APP_ENV'] = 'production'
  #   Sample.env.production?  # => false
  #   Sample.env!.production? # => true
  def env!
    env(true)
  end

  # Set the runtime environment (without affecting environment variables)
  # @param environment [#to_s]
  # @return [ActiveSupport::EnvironmentInquirer]
  # @example
  #   ENV['SAMPLE_ENV'] = 'test'
  #   module Sample
  #     extend AppConfigFor
  #   end
  #   Sample.env        # => 'test'
  #   Sample.env = 'development'
  #   Sample.env        # => 'development'
  #   ENV['SAMPLE_ENV'] # => 'test'
  def env=(environment)
    @env = ActiveSupport::EnvironmentInquirer.new(environment.to_s)
  end

  # Current runtime environment inheritance style. Defaults to +:namespace+.
  # @return [Symbol]
  def env_inheritance
    @env_inheritance ||= :namespace
  end

  # Set the runtime environment inheritance.
  # @param style [#to_s] New inheritance style
  # @return [Symbol]
  # @raise InvalidEnvInheritanceStyle - Attempt to set a style that is not one of the {EnvInheritanceStyles}.
  # @see .verified_style! Valid inheritance styles
  def env_inheritance=(style)
    @env_inheritance = AppConfigFor.verified_style!(style)
  end

  # The name of the current runtime environment for this object.
  #
  # Convenience method for {.env_name AppConfigFor.env_name}({#env_prefixes env_prefixes})
  #
  # If no value can be found, the default is 'development'.
  # @return [String] current runtime environment.
  # @see #env_prefixes Environment variable prefixes
  def env_name
    AppConfigFor.env_name(env_prefixes)
  end

  # Prefixes used to determine the environment name.
  #
  # A prefix of :some_app will will cause AppConfigFor to react to the environment variable +'SOME_APP_ENV'+
  # The order of the prefixes will be the order in which AppConfigFor searches the environment variables.
  # A prefix for +self+ is automatically added at the time of extension/inclusion of AppConfigFor.
  #
  # @param all [Boolean] Combine current prefixes with inherited prefixes.
  # @param dup [Boolean] Return a duplicate of the internal array to prevent accidental modification.
  # @return [Array<Symbol>] Environment prefixes for this object.
  # @see add_env_prefix Adding a prefix
  # @see remove_env_prefix Removing a prefix
  # @see env_name Current runtime environment
  def env_prefixes(all = true, dup = true)
    unless @env_prefixes
      @env_prefixes = []
      add_env_prefix
    end
    if all
      @env_prefixes + AppConfigFor.progenitor_prefixes_of(self)
    else
      dup ? @env_prefixes.dup : @env_prefixes
    end
  end

  # Allow access to configuration getters and setters directly from the extending class/module.
  # @example
  #   class Sample
  #     extend AppConfigFor
  #   end
  # 
  #   # Presuming config/sample.yml contains a configuration for 'log_level' and 'status' but no other keys.
  #   Sample.log_level          # => :production
  #   Sample.log_level = :debug 
  #   Sample.log_level          # => :debug
  # 
  #   # You are allowed to set the value prior reading it should the need should arise.
  #   Sample.status = 'active'  
  #   Sample.status             # => 'active'
  # 
  #   # However, you cannot invent new keys with these methods.
  #   Sample.something_else     # => NoMethodError(undefined method `something_else' for Sample)
  #   Sample.something_else = 1 # => NoMethodError(undefined method `something_else=' for Sample)
  # @note Values can be written or read prior to the loading of the configuration presuming the configuration can load without error.
  def method_missing(name, *args, &block)
    if configured?(name.to_s.split('=').first.to_sym)
      configured.send(name, *args, &block)
    else
      begin
        super
      rescue Exception => e
        # Remove the call to super from the backtrace to make it more apparent where the failure occurred,
        super_line = Regexp.new("#{__FILE__}:#{__LINE__ - 3}") 
        e.set_backtrace(ActiveSupport::BacktraceCleaner.new.tap { |bc| bc.add_silencer { |line| line =~ super_line } }.clean(e.backtrace))
        raise e
      end
    end
  end
  
  # Remove an environmental prefix from the existing list. 
  # @param prefix [Symbol, Object] Prefix to remove.  
  #  +nil+ is treated as +self+   
  #  Non symbols are converted via {.prefix_from AppConfigFor.prefix_from}.  
  # @param all [Boolean] Remove this prefix throughout the entire inheritance chain.  
  #  +USE WITH CAUTION:+ When +true+ this will affect other consumers of AppConfigFor by altering their env prefix values.
  # @return [Array<Symbol>] Current prefixes (without inheritance)
  # @see #env_prefixes Current prefixes
  def remove_env_prefix(prefix, all = false)
    if all
      remove_env_prefix(prefix)
      AppConfigFor.progenitor_of(self)&.remove_env_prefix(prefix, all)
    else
      env_prefixes(false, false).delete(AppConfigFor.prefix_from(prefix))
    end
    env_prefixes(all)
  end

  # Return true if the missing method is a configuration getter or setter.
  # @see #method_missing Accessing configuration values directly from the extending class/module
  def respond_to_missing?(name, *args)
    configured?(name.to_s.split('=').first.to_sym) || super
  end
  
  class << self

    # Add an additional environmental prefix to be used when determining current environment.
    # @param prefix [Symbol, Object] Prefix to add.  
    #  Non symbols are converted via {.prefix_from}.  
    # @param at_beginning [Boolean] where to insert the new prefix with respect to existing prefixes.
    #   * +true+ - Add to the beginning of the list.
    #   * +false+ - Add to the end of the list.
    # @return [Array<Symbol>] Current prefixes (without inheritance)
    # @see env_prefixes Current prefixes
    # @note Prefixes added here will affect all consumers of AppConfigFor. For targeted changes see: {#add_env_prefix}
    def add_env_prefix(prefix, at_beginning = true)
      env_prefixes(false, false).send(at_beginning ? :unshift : :push, prefix_from(prefix)).uniq!
      env_prefixes(false)
    end

    # The name of the current runtime environment. This is value of the first non blank environment variable.
    # If no value can be found, the default is 'development'.
    # Prefixes like +:some_app+, +:rails+, and +:rack+ convert to +'SOME_APP_ENV'+, +'RAILS_ENV'+, and +'RACK_ENV'+ respectively.
    # @param prefixes [Array<#to_s>] List of prefixes of environment variables to check.
    # @return [String] current runtime environment.
    # @see env_prefixes Current prefixes
    def env_name(prefixes = env_prefixes)
      Array(prefixes).inject(nil) { |current_env, name| current_env || ENV["#{name.to_s.upcase}_ENV"].presence } || 'development'
    end

    # Prefixes used to determine the environment name.
    #
    # A prefix of :some_app will will cause AppConfigFor to react to the environment variable +'SOME_APP_ENV'+
    # The order of the prefixes will be the order in which AppConfigFor searches the environment variables.
    #
    # @param _ Ignored. Unlike {#env_prefixes}, the first parameter is ignored as there is no inheritance at this point.
    # @param dup[Boolean] Return a duplicate of the internal array to prevent accidental modification.
    # @return [Array<Symbol>] Defaults to +[:rails, :rack]+
    # @see env_name Current runtime environment
    def env_prefixes(_ = true, dup = true)
      @env_prefixes ||= [:rails, :rack]
      dup ? @env_prefixes.dup : @env_prefixes
    end

    # Lexical namespace of an object.
    # Strings are considered to hold the #name of a Class or Module.
    # Anything not a String, Class, or Module will return the namespace of the class of the object.
    # @param object [Module, Class, String, Object]
    # @return [Module, Class, nil] +nil+ is returned if there is no surrounding namespace.
    # @example
    #   module Some
    #     class App
    #     end
    #   end
    #
    #   namespace_of(Some::App)      # => Some
    #   namespace_of('Some::App')    # => Some
    #   namespace_of(Some::App.new)  # => Some
    #   namespace_of(Some)           # => nil
    def namespace_of(object)
      (String === object ? object : nearest_named_class(object).name).deconstantize.safe_constantize
    end

    # Array of all hierarchical lexical namespaces of an object. Uses {.namespace_of}
    # @param object [Module, Class, String, Object]
    # @return [Array<Module, Class>]
    # @example
    #   module Some
    #     class App
    #       class Connection
    #       end
    #     end
    #   end
    #
    #   namespaces_of(Some::App::Connection) # => [Some::App, Some]
    #   namespaces_of(Some) # => []
    def namespaces_of(object)
      (object = [namespace_of(object)]).each { |x| x && object << namespace_of(x) }[0..-2]
    end
    
    # Locate the nearest class that is not anonymous.
    # @param object [Object]
    # @return [Class] The first non-anonymous class that is in the class hierarchy.
    def nearest_named_class(object)
      # Switch from an instance to a class
      object = object.class unless object.is_a?(Module)
      # Switch from anonymous module to a class unless it provides a name
      object = object.class unless object.try(:name) || object.respond_to?(:superclass)
      # Continue up the hierarchy while we are in an anonymous class
      object = object.superclass while object.name.nil?
      object
    end
    
    # Parent of an object.
    # While similar to inheritance it provides a meaningful value for strings and other objects.
    # Classes return super classes.
    # Strings are treated as a name of a class and an attempt is made to locate that class (not the superclass of the named class).
    # All other objects return the class of the object.
    # @param object [Class, String, Object]
    # @return [Class, nil] +nil+ is returned if a string is given that is not the name of a class.
    # @example
    #   module Some
    #     class Base
    #     end
    #     class App < Base
    #     end
    #   end
    #
    #   parent_of(Some::App)     # => Some::Base
    #   parent_of(Some::App.new) # => Some::App
    #   parent_of('Some::App')   # => Some::App
    #   parent_of('wtf')         # => nil
    def parent_of(object)
      case object
      when String
        object.safe_constantize
      when Class
        object.superclass
      else
        object.class
      end
    end

    # List of all hierarchical parents of an object. Uses {.parents_of}
    # @param object [Class, String, Object]
    # @return [Array<Class>]
    #
    # @example
    #   module Some
    #     class Base
    #     end
    #     class App < Base
    #     end
    #   end
    #
    #   parents_of(Some::App)     # => [Some::Base, Object, BasicObject]
    #   parents_of(Some::App.new) # => [Some::App, Some::Base, Object, BasicObject]
    #   parents_of('Some::App')   # => [Some::App, Some::Base, Object, BasicObject]
    #   parents_of('wtf')         # => []
    def parents_of(object)
      (object = [parent_of(object)]).each { |x| x && object << parent_of(x) }[0..-2]
    end

    # Converts an object to a prefix symbol.
    # Non symbols are converted to underscored symbols with '/' characters changed to underscores.
    # Conversion by object type is as follows:
    # * Symbol -> symbol
    # * Module -> module.name
    # * Class -> class.name
    # * String -> string
    # * Pathname -> pathname.basename (Without an extension)
    # * other -> other.class.name
    # @param object [Symbol, Module, Class, String, Pathname, Object] object to convert to a prefix
    # @return [Symbol]
    # @example
    #   module Some
    #     class App
    #     end
    #   end
    #
    #   # All of the following return :some_app
    #   prefix_from(Some::App)
    #   prefix_from('Some::App')
    #   prefix_from(Some::App.new)
    #   prefix_from(:some_app)
    #   prefix_from(Pathname.new('/foo/bar/some_app.yml'))
    def prefix_from(object)
      if object.is_a?(Symbol)
        object
      else
        case object
        when String
          object
        when Pathname
          object.basename('.*').to_s
        else
          nearest_named_class(object).name
        end.underscore.gsub('/','_').to_sym
     end
    end

    # The first env_prefix aware namespace/parent of an object. 
    # Search is dependant on the inheritance style given.
    # @param object [Object] Object to retrieve the progenitor of.
    # @param style [#to_s] Type of hierarchical traversal.
    # @return [Object, nil] +nil+ is returned if there is no progenitor.
    # @raise InvalidEnvInheritanceStyle - Attempt to use a style that is not one of the {EnvInheritanceStyles}.
    # @see .verified_style! Valid inheritance styles
    def progenitor_of(object, style = nil)
      style = verified_style!(style, object)
      command = {namespace: :namespace_of, class: :parent_of}[style.to_s.split('_').first.to_sym]
      object && command && send(command, object).yield_self { |n| n && (n.respond_to?(:env_prefixes) ? n : progenitor_of(n)) }
    end

    # Extract the env_prefixes from the progenitor of the given object.
    # @param object [Object] Object to retrieve the {.progenitor_of} and subsequently the {#env_prefixes}.
    # @param style [#to_s] Type of hierarchical traversal.
    # @param all [Boolean] Return inherited prefixes.  
    #   If there is no progenitor of the object and all is +true+ then {.env_prefixes AppConfigFor.env_prefixes} will be returned.
    # @return [Array<Symbol>] Environment prefixes for this object.
    # @raise InvalidEnvInheritanceStyle - Attempt to use a style that is not one of the {EnvInheritanceStyles}.
    # @see .env_prefixes Default prefixes
    # @see .verified_style! Valid inheritance styles
    def progenitor_prefixes_of(object, style = nil, all = true)
      Array((progenitor_of(object, style) || all && AppConfigFor).try(:env_prefixes, all))
    end

    # List of hierarchical progenitors of an object.
    # Hierarchical precedence is controlled by the style.
    # @param object [Object] Object to get the progenitors from
    # @param style [#to_s] Type of hierarchical traversal.
    # @param unique [Boolean] Remove duplicate progenitors.
    # @return [Array<Object>]
    # @raise InvalidEnvInheritanceStyle - Attempt to use a style that is not one of the {EnvInheritanceStyles}.
    # @see progenitor_of Progenitor of an object
    # @see .verified_style! Valid inheritance styles
    def progenitors_of(object, style = nil, unique = true)
      style = verified_style!(style, object)
      unique = unique && style != :none
      if object && style != :none
        styles = style.to_s.split('_')
        if styles.size > 1
          styles.flat_map { |style| progenitors_of(object, style, false) }
        else
          Array(progenitor_of(object, style)).yield_self { |x| x + progenitors_of(x.last, nil, false) }
        end
      else
        []
      end.yield_self { |result| unique ? result.reverse.uniq.reverse + [self] : result }
    end

    # Remove an environmental prefix from the existing list. 
    # @param prefix [Symbol, Object] Prefix to remove.  
    #  Non symbols are converted via {.prefix_from AppConfigFor.prefix_from}.  
    # @param _ Ignored. Unlike {#remove_env_prefix}, the first parameter is ignored as there is no inheritance at this point.
    # @return [Array<Symbol>] Current prefixes (without inheritance)
    # @note Prefixes removed here will affect all consumers of AppConfigFor. For targeted changes see: {#remove_env_prefix}
    def remove_env_prefix(prefix, _ = false)
      env_prefixes(false, false).delete(prefix_from(prefix))
      env_prefixes(false)
    end

    # Verifies the inheritance style. If style is nil, the object, if given, will be queried for its env_inheritance.
    # Otherwise the style will default to +:namespace:+
    # @param style [#to_s] Inheritance style to verify.
    # @param object [Object] Object to query for env_inheritance if style is nil.
    # return [Symbol] A valid inheritance style.
    # @raise InvalidEnvInheritanceStyle - An invalid inheritance style was received.
    def verified_style!(style = nil, object = nil)
      style ||= object.respond_to?(:env_inheritance) && object.env_inheritance || :namespace
      style = style.try(:to_sym) || style.to_s.to_sym
      EnvInheritanceStyles.include?(style) ? style : raise(InvalidEnvInheritanceStyle.new(style))
    end

    # Determine the name of the yml file from the object given. No pathing is assumed.
    # Anything not a Pathname is converted to an underscored string with '/' characters changed to underscores and a '.yml' extension
    # @param object [Object] Object to determine a yml name from.
    #
    # Determination by object type is as follows:
    # * Pathname -> pathname
    # * Module -> module.name
    # * Class -> class.name
    # * String -> string
    # * Symbol -> symbol.to_s
    # * other -> other.class.name
    # @return [String, Pathname]
    # @example
    #   module Some
    #     class App
    #     end
    #   end
    #
    #   # All of the following return 'some_app.yml'
    #   yml_name_from(Some::App)
    #   yml_name_from(Some::App.new)
    #   yml_name_from(:some_app)
    #   yml_name_from('Some/App')
    #   yml_name_from('Some::App')
    #
    #   # Pathnames receive no conversion
    #   yml_name_from(Pathname.new('not/a/yml_file.txt')) # => #<Pathname:not/a/yml_file.txt>
    def yml_name_from(object)
      if object.is_a?(Pathname)
        object
      else
        case object
        when String
          object
        when Symbol
          object.to_s
        else
          nearest_named_class(object).name
        end.underscore.gsub('/','_') + '.yml'
      end
    end
    
    private

    # Add the config directory from the gem installation if this is a gem.
    def add_gem_directory(base)
      gem = Gem.loaded_specs[base.name.underscore]
      base.add_config_directory(gem.gem_dir + '/config') if gem
    end

    def extended(base)
      # Todo: Add the ability to check the default environments directly from base if the methods don't yet exist.
      # ie: base.development? is the same as base.env.development?
      add_gem_directory(base)
    end

    def included(base)
      add_gem_directory(base)
    end

  end

end