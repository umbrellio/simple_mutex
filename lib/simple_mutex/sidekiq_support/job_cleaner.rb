# frozen_string_literal: true

module SimpleMutex
  module SidekiqSupport
    class JobCleaner < ::SimpleMutex::BaseCleaner
      class << self
        def unlock_dead_jobs
          new.unlock
        end
      end

      private

      def type
        "Job"
      end

      def path_to_entity_id
        %w[payload jid]
      end

      def active_entity_ids
        ::Sidekiq::Workers.new.map { |_pid, _tid, work| work["payload"]["jid"] }
      end
    end
  end
end
