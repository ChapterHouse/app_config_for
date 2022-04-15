# frozen_string_literal: true
require_relative "gem_version"

module AppConfigFor

  # Current version of this gem.
  # @return [Gem::Version]
  # @see gem_version
  def self.version
    gem_version
  end

end
