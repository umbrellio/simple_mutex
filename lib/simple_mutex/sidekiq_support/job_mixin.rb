# frozen_string_literal: true

module SimpleMutex
  module SidekiqSupport
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

      def with_redlock(args = [], &)
        return yield unless self.class.locking?

        options = {
          params:           args,
          lock_with_params: self.class.lock_with_params?,
        }

        options[:expires_in] = self.class.job_timeout unless self.class.job_timeout.nil?

        ::SimpleMutex::SidekiqSupport::JobWrapper.new(self, **options).with_redlock(&)
      rescue SimpleMutex::Mutex::LockError => error
        process_locking_error(error)
      end

      # override for custom processing
      def process_locking_error(error)
        raise error unless self.class.skip_locking_error?
      end
    end
  end
end
