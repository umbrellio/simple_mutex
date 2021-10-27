# frozen_string_literal: true

module SimpleMutex
  class BatchCallbacks
    def on_death(_status, options)
      SimpleMutex::Mutex.unlock!(options["lock_key"], signature: options["signature"])
    end

    def on_success(_status, options)
      SimpleMutex::Mutex.unlock!(options["lock_key"], signature: options["signature"])
    end
  end
end
