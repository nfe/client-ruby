# frozen_string_literal: true

require_relative "lib/nfe/version"

Gem::Specification.new do |spec|
  spec.name = "nfe-io"
  spec.version = Nfe::VERSION
  spec.authors = ["NFE.io Team"]
  spec.email = ["suporte@nfe.io"]

  spec.summary = "Official NFE.io SDK for Ruby"
  spec.description = "Official NFE.io SDK for Ruby — modern Ruby (3.2+), zero runtime " \
                     "dependencies, for issuing and managing Brazilian electronic fiscal " \
                     "documents (NFS-e, NF-e, NFC-e, CT-e)."
  spec.homepage = "https://nfe.io"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/nfe/client-ruby",
    "changelog_uri" => "https://github.com/nfe/client-ruby/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/nfe/client-ruby/blob/master/README.md",
    "bug_tracker_uri" => "https://github.com/nfe/client-ruby/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "README.md",
    "MIGRATION.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  # Zero runtime dependencies — Ruby stdlib only (net/http, json, openssl, uri, ...).
  # Development tooling only:
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rbs", "~> 3.4"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.75"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "steep", "~> 1.7"
  spec.add_development_dependency "yard", "~> 0.9"
end
