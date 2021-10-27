# frozen_string_literal: true

module SimpleMutex
  module JobMixin
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def locking!
        @locking = true
      end

      def locking?
        !!@locking
      end

      def skip_locking_error!
        @skip_locking_error = true
      end

      def skip_locking_error?
        !!@skip_locking_error
      end

      def lock_with_params!
        @lock_with_params = true
      end

      def lock_with_params?
        !!@lock_with_params
      end

      def set_job_timeout(value)
        @job_timeout = value
      end

      def job_timeout
        @job_timeout
      end
    end

    def with_redlock(args = [], &block)
      return yield unless self.class.locking?

      SimpleMutex::Job.new(
        self,
        params:           args,
        lock_with_params: self.class.lock_with_params?,
        mutex_ttl:        self.class.job_timeout,
      ).with_redlock(&block)
    rescue SimpleMutex::Mutex::LockError => error
      process_locking_error(error)
    end

    # override for custom processing
    def process_locking_error(error)
      raise error unless self.class.skip_locking_error?
    end
  end
end
