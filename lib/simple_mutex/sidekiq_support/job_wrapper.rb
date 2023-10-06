# frozen_string_literal: true

module SimpleMutex
  module SidekiqSupport
    class JobWrapper
      attr_reader :job, :params, :lock_key, :lock_with_params, :expires_in

      DEFAULT_EXPIRES_IN = 5 * 60 * 60 # 5 hours

      def initialize(job,
                     params:           [],
                     lock_key:         nil,
                     lock_with_params: false,
                     expires_in:       DEFAULT_EXPIRES_IN)
        self.job              = job
        self.params           = params

        self.lock_key         = lock_key
        self.lock_with_params = lock_with_params
        self.expires_in       = expires_in
      end

      def with_redlock(&block)
        ::SimpleMutex::Mutex.with_lock(
          lock_key || generate_lock_key,
          expires_in: expires_in,
          payload:    generate_payload,
          &block
        )
      end

      private

      attr_writer :job, :params, :lock_key, :lock_with_params, :expires_in

      def generate_lock_key
        key = if lock_with_params
                "#{job.class.name}<#{params.to_json}>"
              else
                job.class.name
              end
        key.tr(":", "_")
      end

      def generate_payload
        { "type"       => "Job",
          "started_at" => Time.now.to_s,
          "jid"        => job.jid }
      end
    end
  end
end
