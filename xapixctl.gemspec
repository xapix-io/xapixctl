# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "xapixctl/version"

Gem::Specification.new do |spec|
  spec.name          = "xapixctl"
  spec.version       = Xapixctl::VERSION
  spec.authors       = ["Michael Reinsch"]
  spec.email         = ["michael@xapix.io"]

  spec.summary       = 'xapix client library and command line tool'
  spec.homepage      = "https://github.com/xapix-io/xapixctl"
  spec.license       = "EPL-2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency "activesupport", ">= 5.2.3", "< 6.0.0"
  spec.add_dependency "rest-client", ">= 2.1.0", "< 3.0.0"
  spec.add_dependency "thor", ">= 1.0.0", "< 1.2.0"

  spec.add_development_dependency "bundler", "~> 2.1.4"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "relaxed-rubocop", "~> 2.5"
  spec.add_development_dependency "rspec", "~> 3.10.0"
  spec.add_development_dependency "rubocop", "~> 1.11.0"
  spec.add_development_dependency "rubocop-rake", "~> 0.5.1"
  spec.add_development_dependency "rubocop-rspec", "~> 2.2.0"
  spec.add_development_dependency "webmock", "~> 3.12.1"
end
