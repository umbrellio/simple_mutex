# frozen_string_literal: true

require "forwardable"

module SimpleMutex
  class Batch
    class Error < StandardError; end

    attr_accessor :batch, :lock_key

    extend Forwardable

    def_delegators :@batch, :on, :bid, :description, :description=

    def initialize(lock_key:, mutex_options:)
      SimpleMutex.sidekiq_pro_check!

      self.lock_key = lock_key
      self.batch = Sidekiq::Batch.new
      self.mutex = SimpleMutex::Mutex.new(
        lock_key,
        **mutex_options.merge(
          payload: generate_payload(batch),
        ),
      )
    end

    def jobs(&block)
      mutex.lock!
      signature = mutex.signature

      batch.on(:death,   SimpleMutex::BatchCallbacks, "lock_key"  => lock_key,
                                                      "signature" => signature)
      batch.on(:success, SimpleMutex::BatchCallbacks, "lock_key"  => lock_key,
                                                      "signature" => signature)
      begin
        batch.jobs(&block)
      rescue => error
        mutex.unlock!
        raise error
      end

      status = Sidekiq::Batch::Status.new(batch.bid)

      if status.total.zero?
        mutex.unlock!
        raise Error, "Batch should contain at least one job."
      end
    end

    private

    def sidekiq_pro_installed?
      Object.const_defined?("Sidekiq::Pro::VERSION")
    end

    def no_sidekiq_pro_msg
      "SimpleMutex::Batch requires Sidekiq Pro to be installed."
    end

    def generate_payload(batch)
      { "type"       => "Batch",
        "started_at" => Time.now.to_s,
        "bid"        => batch.bid }
    end

    attr_accessor :mutex
  end
end
