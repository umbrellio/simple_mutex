# frozen_string_literal: true

module SimpleMutex
  module SidekiqSupport
    class BatchCleaner < ::SimpleMutex::BaseCleaner
      class << self
        def unlock_dead_batches
          new.unlock
        end
      end

      def initialize
        ::SimpleMutex.sidekiq_pro_check!
        super
      end

      private

      def type
        "Batch"
      end

      def path_to_entity_id
        %w[payload bid]
      end

      def active_entity_ids
        ::Sidekiq::BatchSet.new.map(&:bid)
      end
    end
  end
end
