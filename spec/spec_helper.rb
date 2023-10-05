# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = "coverage/lcov.info"
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter,
])

SimpleCov.start { add_filter "spec" }

require "bundler/setup"
require "simple_mutex"
require "json"
require "redis"
require "redis-namespace"
require "timecop"
require "mock_redis"

require_relative "support/stubs"

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end
end

# Redis server used for testing
SimpleMutex.redis = Redis::Namespace.new(
  :simple_mutex_testing,
  redis: MockRedis.new,
)
