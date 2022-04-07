# frozen_string_literal: true

require_relative "app_config_for/version"
require_relative "app_config_for/errors"
require 'active_support/environment_inquirer'
require 'active_support/configuration_file'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require "active_support/core_ext/hash/indifferent_access"
require 'active_support/ordered_options'
require 'active_support/core_ext/object/try'

module AppConfigFor

  def initialize(*args)
    add_env_prefix
    super
  end

  def add_env_prefix(prefix = nil, at_beginning: true)
    env_prefixes(all: false, dup: false).send(at_beginning ? :unshift : :push, AppConfigFor.prefix_from(prefix || self)).uniq!
  end

  def config_directories
    directories = ['Rails'.safe_constantize&.application&.paths, try(:paths)].compact.map { |root| Pathname.new(root["config"].existent.first) }
    directories.push(Pathname.getwd + 'config')
    directories.uniq
  end

  def config_file(name = nil)
    unless name.is_a?(Pathname)
      config_files(name).find(&:exist?)
    else
      name.exist? ? name.expand_path : nil
    end
  end

  def config_files(name = nil)
    name = AppConfigFor.yml_name_from(name || self)
    config_directories.map { |directory| directory + name }
  end

  def config_file?(name = nil)
    !config_file(name).blank?
  end

  def config_for(name, environment: nil)
    config, shared = config_options(name).fetch_values((environment || env).to_sym, :shared) {nil}
    config ||= shared

    if config.is_a?(Hash)
      config = shared.deep_merge(config) if shared.is_a?(Hash)
      config = ActiveSupport::OrderedOptions.new.update(config)
    end

    config
  end

  def config_options(name = nil)
    file = name.is_a?(Pathname) ? name : config_file(name)
    ActiveSupport::ConfigurationFile.parse(file.to_s).deep_symbolize_keys
  rescue SystemCallError => exception
    raise ConfigNotFound.new(name.is_a?(Pathname) ? name : config_files(name), exception)
  rescue => exception
    raise LoadError.new(file, exception)
  end

  def configured(environment: nil)
    config_for(self, environment: environment)
  end

  def env(reload: false)
    @env = ActiveSupport::EnvironmentInquirer.new(AppConfigFor.env_name(env_prefixes)) if reload || @env.nil?
    @env
  end

  def env_prefixes(all: true, dup: true)
    @env_prefixes ||= []
    if all
      @env_prefixes + AppConfigFor.progenitor_of(self).env_prefixes(all: true)
    else
      dup ? @env_prefixes.dup : @env_prefixes
    end
  end

  def remove_env_prefix(prefix, all: false)
    if all
      remove_env_prefix(prefix)
      AppConfigFor.progenitor_of(self).remove_env_prefix(prefix, all: true)
    else
      env_prefixes(all: false, dup: false).delete(AppConfigFor.prefix_from(prefix))
    end
  end

  class << self

    def add_env_prefix(prefix)
      env_prefixes(dup: false).push(prefix_from(prefix))
    end

    def env_name(prefixes = env_prefixes)
      prefixes.inject(nil) { |current_env, name| current_env || ENV["#{name.to_s.upcase}_ENV"].presence } || 'development'
    end

    def env_prefixes(all: true, dup: true)
      # all is ignored as we are at the end of the chain
      @env_prefixes ||= [:rails, :rack]
      dup ? @env_prefixes.dup : @env_prefixes
    end

    def namespace_of(object)
      case object
      when String
        object
      when Module
        object.name
      else
        object.class.name
      end.deconstantize.safe_constantize
    end

    def prefix_from(object)
      if object.is_a?(Symbol)
        object
      else
        case object
        when Module
          object.name
        when String
          object
        when Pathname
          object.basename.to_s
        else
          object.class.name
        end.underscore.gsub('/','_').to_sym
     end

    end

    # First namespace of the object that supports env_prefixes or AppConfig
    def progenitor_of(object)
      (namespace_of(object) || self).yield_self do |namespace|
        namespace.respond_to?(:env_prefixes) ? namespace : progenitor_of(namespace)
      end
    end

    def remove_env_prefix(prefix, all: false)
      # all is ignored as we are at the end of the chain
      env_prefixes(dup: false).delete(prefix_from(prefix))
    end

    def yml_name_from(object)
      if object.is_a?(Pathname)
        object
      else
        case object
        when Module
          object.name
        when String, Symbol
          object.to_s
        else
          object.class.name
        end.underscore.gsub('/','_') + '.yml'
      end
    end

    private

    def extended(base)
      # Todo: Add the ability to check the default environments directly from base if the methods don't yet exist.
      # ie: base.development? is the same as base.env.development?
      base.add_env_prefix
    end

    # Todo: Determine progenitor_of with respect to combining inheritance with namespace scoping
    # def included(base)
    #   base.add_env_prefix
    # end

  end

end
