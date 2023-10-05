# frozen_string_literal: true

require "forwardable"

module SimpleMutex
  module SidekiqSupport
    class Batch
      extend Forwardable

      DEFAULT_EXPIRES_IN = 6 * 60 * 60

      class Error < StandardError; end

      attr_reader :batch, :lock_key, :expires_in

      def_delegators :@batch, :on, :bid, :description, :description=

      def initialize(lock_key:, expires_in: DEFAULT_EXPIRES_IN)
        ::SimpleMutex.sidekiq_pro_check!

        self.lock_key   = lock_key
        self.expires_in = expires_in
        self.batch      = ::Sidekiq::Batch.new
      end

      def jobs(&)
        mutex.lock!

        set_callbacks(mutex.signature)

        begin
          batch.jobs(&)
        rescue => error
          mutex.unlock!
          raise error
        end

        status = ::Sidekiq::Batch::Status.new(batch.bid)

        if status.total.zero?
          mutex.unlock!
          raise Error, "Batch should contain at least one job."
        end
      end

      private

      attr_writer :batch, :lock_key, :expires_in

      def mutex
        return @mutex if defined? @mutex

        @mutex = ::SimpleMutex::Mutex.new(
          lock_key,
          expires_in:,
          payload:    generate_payload(batch),
        )
      end

      def generate_payload(batch)
        { "type"       => "Batch",
          "started_at" => Time.now.to_s,
          "bid"        => batch.bid }
      end

      def set_callbacks(signature)
        %i[death success].each do |event|
          batch.on(
            event,
            ::SimpleMutex::SidekiqSupport::BatchCallbacks,
            "lock_key"  => lock_key,
            "signature" => signature,
          )
        end
      end
    end
  end
end
