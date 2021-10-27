# frozen_string_literal: true

module SimpleMutex
  class Job
    attr_reader :job, :lock_key, :lock_with_params, :params, :mutex_ttl

    def initialize(job,
                   lock_key:         nil,
                   lock_with_params: false,
                   params:           [],
                   mutex_ttl:        5 * 60 * 60)
      self.job              = job
      self.lock_key         = lock_key
      self.lock_with_params = lock_with_params
      self.params           = params
      self.mutex_ttl        = mutex_ttl
    end

    def with_redlock
      SimpleMutex::Mutex.with_lock(
        lock_key || generate_lock_key,
        expire:  mutex_ttl * 1000,
        payload: mutex_payload,
      ) { yield }
    end

    private

    attr_writer :job, :lock_key, :lock_with_params, :params, :mutex_ttl

    def generate_lock_key
      key = if lock_with_params
              "#{job.class.name}<#{params.to_json}>"
            else
              job.class.name
            end
      key.tr(":", "_")
    end

    def mutex_payload
      { "type"       => "Job",
        "started_at" => Time.now.to_s,
        "jid"        => job.jid }
    end
  end
end
