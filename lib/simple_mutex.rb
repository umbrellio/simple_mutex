# frozen_string_literal: true

module SimpleMutex
  require_relative "simple_mutex/version"
  require_relative "simple_mutex/mutex"

  require_relative "simple_mutex/base_cleaner"

  require_relative "simple_mutex/sidekiq_support/job_wrapper"
  require_relative "simple_mutex/sidekiq_support/job_cleaner"
  require_relative "simple_mutex/sidekiq_support/job_mixin"

  require_relative "simple_mutex/sidekiq_support/batch"
  require_relative "simple_mutex/sidekiq_support/batch_callbacks"
  require_relative "simple_mutex/sidekiq_support/batch_cleaner"

  require_relative "simple_mutex/helper"

  class Error < StandardError; end

  class << self
    attr_accessor :redis, :logger
  end

  def redis_check!
    raise Error, no_redis_error unless redis
  end

  def sidekiq_pro_check!
    raise Error, no_sidekiq_pro_error unless sidekiq_pro_installed?
  end

  def sidekiq_pro_installed?
    Object.const_defined?("Sidekiq::Pro::VERSION")
  end

  def no_redis_error
    "You should set SimpleMutex.redis before using any functions of this gem."
  end

  def no_sidekiq_pro_error
    "Batch related functionality requires Sidekiq Pro to be installed."
  end

  module_function :redis_check!, :sidekiq_pro_check!, :sidekiq_pro_installed?,
                  :no_redis_error, :no_sidekiq_pro_error
end
