# frozen_string_literal: true

require_relative "lib/simple_mutex/version"

Gem::Specification.new do |spec|
  spec.name          = "simple_mutex"
  spec.version       = SimpleMutex::VERSION
  spec.authors       = ["bob-umbr"]
  spec.email         = ["bob@umbrellio.biz"]

  spec.summary       = "Redis-based mutex library for using with sidekiq jobs and batches."
  spec.description   = "Redis-based mutex library for using with sidekiq jobs and batches."
  spec.homepage      = "https://github.com/umbrellio/simple_mutex"
  spec.license       = "MIT"

  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "redis", ">= 5.0"
  spec.add_runtime_dependency "sidekiq"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "mock_redis"
  spec.add_development_dependency "redis-namespace", ">= 1.8.2"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-config-umbrellio"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-lcov"
  spec.add_development_dependency "timecop"
end
