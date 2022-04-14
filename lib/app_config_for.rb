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

require 'active_support/configuration_file'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/ordered_options'
require 'active_support/core_ext/object/try'

module AppConfigFor

  EnvPrefixInheritanceStyles = %i(none namespace class namespace_class class_namespace)

  def initialize(*args)
    add_env_prefix
    super
  end

  def add_env_prefix(prefix = nil, at_beginning = true)
    env_prefixes(false, false).send(at_beginning ? :unshift : :push, AppConfigFor.prefix_from(prefix || self)).uniq!
  end

  def add_config_directory(new_directory)
    (additional_config_directories << Pathname.new(new_directory).expand_path).uniq!
  end

  def additional_config_directories
    @additional_config_directories ||= []
  end

  def config_directories
    directories = ['Rails'.safe_constantize&.application&.paths, try(:paths)].compact.map { |root| root["config"].existent.first }.compact
    directories.map! { |directory| Pathname.new(directory).expand_path }
    directories.concat additional_config_directories
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
    name = AppConfigFor.yml_name_from(name || config_name)
    config_directories.map { |directory| directory + name }
  end

  def config_file?(name = nil)
    !config_file(name).blank?
  end

  def config_for(name, env: nil)
    config, shared = config_options(name).fetch_values((env || self.env).to_sym, :shared) {nil}
    config ||= shared

    if config.is_a?(Hash)
      config = shared.deep_merge(config) if shared.is_a?(Hash)
      config = ActiveSupport::OrderedOptions.new.update(config)
    end

    config
  end

  def config_name
    @config_name ||= self
  end

  def config_name=(new_config_name)
    @config_name = new_config_name
  end

  def config_options(name = nil)
    file = name.is_a?(Pathname) ? name : config_file(name)
    ActiveSupport::ConfigurationFile.parse(file.to_s).deep_symbolize_keys
  rescue SystemCallError => exception
    raise ConfigNotFound.new(name.is_a?(Pathname) ? name : config_files(name), exception)
  rescue => exception
    raise file ? LoadError.new(file, exception) : exception
  end

  def configured(reload = false, env: nil)
    @configured = config_for(nil, env: env) if reload || @configured.nil?
    @configured
  end

  def env(reload = false)
    @env = ActiveSupport::EnvironmentInquirer.new(AppConfigFor.env_name(env_prefixes)) if reload || @env.nil?
    @env
  end

  def env_prefix_inheritance
    @env_prefix_inheritance ||= :namespace
  end

  def env_prefix_inheritance=(style)
    @env_prefix_inheritance = AppConfigFor.verified_style!(style)
  end

  def env_prefixes(all = true, dup = true)
    @env_prefixes ||= []
    if all
      @env_prefixes + AppConfigFor.progenitor_prefixes_of(self)
    else
      dup ? @env_prefixes.dup : @env_prefixes
    end
  end

  def remove_env_prefix(prefix, all = false)
    if all
      remove_env_prefix(prefix)
      AppConfigFor.progenitor_of(self)&.remove_env_prefix(prefix, all)
    else
      env_prefixes(false, false).delete(AppConfigFor.prefix_from(prefix))
    end
  end

  class << self

    def add_env_prefix(prefix, at_beginning = true)
      env_prefixes(false, false).send(at_beginning ? :unshift : :push, prefix_from(prefix)).uniq!
    end

    def env_name(prefixes = env_prefixes)
      prefixes.inject(nil) { |current_env, name| current_env || ENV["#{name.to_s.upcase}_ENV"].presence } || 'development'
    end

    def env_prefixes(_all = true, dup = true)
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

    # Not used internally, this is a convenience method to study what progenitors are used during namespace dives
    def namespaces_of(object)
      (object = [namespace_of(object)]).each { |x| x && object << namespace_of(x) }[0..-2]
    end

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

    # Not used internally, this is a convenience method to study what progenitors are used during class dives
    def parents_of(object)
      (object = [parent_of(object)]).each { |x| x && object << parent_of(x) }[0..-2]
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

    def progenitor_of(object, style = nil)
      style = verified_style!(style, object)
      command = {namespace: :namespace_of, class: :parent_of}[style] # Todo, deal with the other styles by doing nothing and not crashing or something.
      object && command && send(command, object).yield_self { |n| n && (n.respond_to?(:env_prefixes) ? n : progenitor_of(n)) }
    end

    def progenitor_prefixes_of(object, style = nil, all = true)
      Array(progenitor_of(object, style)&.env_prefixes(all))
    end

    def progenitors_of(object, style = nil, terminate = true)
      style = verified_style!(style, object)
      terminate = terminate && style != :none
      if object && style != :none
        styles = style.to_s.split('_')
        if styles.size > 1
          styles.flat_map{ |style| progenitors_of(object, style, false) }
        else
          Array(progenitor_of(object, style)).yield_self { |x| x + progenitors_of(x.last, nil, false) }
        end
      else
        []
      end.yield_self { |result| terminate ? result.reverse.uniq.reverse + [self] : result }
    end

    def remove_env_prefix(prefix, all = false)
      env_prefixes(all, false).delete(prefix_from(prefix))
    end

    def verified_style!(style, object = nil)
      style ||= object.respond_to?(:env_prefix_inheritance) ? object.send(:env_prefix_inheritance) : :namespace
      style = style.try(:to_sym) || style.to_s.to_sym
      EnvPrefixInheritanceStyles.include?(style) ? style : raise(InvalidEnvInheritanceStyle.new(style))
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

    def prep_base(base)
      base.add_env_prefix
      gem = Gem.loaded_specs[base.name.underscore]
      base.add_config_directory(gem.gem_dir + '/config') if gem
    end

    def extended(base)
      # Todo: Add the ability to check the default environments directly from base if the methods don't yet exist.
      # ie: base.development? is the same as base.env.development?
      prep_base(base)
    end

    def included(base)
      prep_base(base)
    end

  end

end

