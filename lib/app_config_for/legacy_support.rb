require 'active_support/core_ext/string/inflections'
name = File.basename(__dir__).classify
STDERR.puts "#{name}: Warning! Outdated version of ActiveSupport active! To avoid security issues, please upgrade your version of ActiveSupport to at least 6.1.4."
if ActiveSupport.gem_version < Gem::Version.new('6.1.0')
  puts "#{name}: Loading legacy support for ActiveSupport version #{ActiveSupport.gem_version}."

  # Quick and dirty backport. This won't be here long. Just enough to support AppConfigFor during some legacy upgrades.
  require "active_support/string_inquirer"
  require "erb"
  require "yaml"

  # @note This legacy support is only included if the existing ActiveSupport version is below 6.1.0. 
  #   If your application is using any version of ActiveSupport below 6.1.4 it is *strongly* suggested you upgrade your application due to security and bug fixes.
  #   This backwards compatability is only enough to support AppConfigFor and is not to be considered a full backport of existing features.
  #   This support will be removed in the future.
  module ActiveSupport

    # @note This legacy support is only included if the existing ActiveSupport version is below 6.1.0. 
    #   If your application is using any version of ActiveSupport below 6.1.4 it is *strongly* suggested you upgrade your application due to security and bug fixes.
    #   This backwards compatability is only enough to support AppConfigFor and is not to be considered a full backport of existing features.
    #   This support will be removed in the future.
    class EnvironmentInquirer < StringInquirer

      # Default environments
      Environments = %w(development test production)

      def initialize(env)
        super(env)
        Environments.each { |e| instance_variable_set(:"@#{e}", env == e) }
      end

      Environments.each { |e| define_method("#{e}?") { instance_variable_get("@#{e}") }}
    end

    # @note This legacy support is only included if the existing ActiveSupport version is below 6.1.0. 
    #   If your application is using any version of ActiveSupport below 6.1.4 it is *strongly* suggested you upgrade your application due to security and bug fixes.
    #   This backwards compatability is only enough to support AppConfigFor and is not to be considered a full backport of existing features.
    #   This support will be removed in the future.
    class ConfigurationFile
      def initialize(file_name)
        @file_name = file_name
        @config = File.read(file_name)
        warn(file_name + ' contains invisible non-breaking spaces.') if @config.match?("\u00A0")
      end

      # Quick and dirty parse
      def self.parse(file_name)
        new(file_name).parse
      end

      # Quick and dirty parse
      def parse
        YAML.load(ERB.new(@config).result) || {}
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{@file_name}. Error: #{e.message}"
      end
    end

  end

end
