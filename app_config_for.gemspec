# frozen_string_literal: true

require_relative "lib/app_config_for/version"

Gem::Specification.new do |spec|
  spec.name = "app_config_for"
  spec.version = AppConfigFor::VERSION
  spec.authors = ["Frank Hall"]
  spec.email = ["ChapterHouse.Dune@gmail.com"]

  spec.summary = "Rails::Application#config_for style capabilities for non-rails applications, gems, and rails engines."
  spec.description = <<-EOF
    Rails::Application#config_for style capabilities for non-rails applications, gems, and rails engines.
    Observes RAILS_ENV, RACK_ENV, and custom env variables.
    For gems and engines, it supports default configs in engine/gem config directory that can be overridden by the consumer 
    of your engine/gem by placing a configuration file in a top level config directory.
  EOF
  spec.homepage = "https://github.com/ChapterHouse/#{spec.name}"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ChapterHouse/#{spec.name}/tree/v#{spec.version}"
  spec.metadata["changelog_uri"] = "https://github.com/ChapterHouse/#{spec.name }/blob/v#{spec.version}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'activesupport', '~> 7.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
