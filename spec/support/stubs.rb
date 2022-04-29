# frozen_string_literal: true

RSpec.shared_context "batch_stub" do
  before do
    batch_class = Class.new
    batch_class.class_exec do
      attr_accessor :description
      attr_reader :bid

      # rubocop:disable RSpec/LeakyConstantDeclaration
      self::JobExecutionError = Class.new(StandardError)

      self::Status = Class.new do
        attr_reader :bid

        def initialize(bid)
          self.bid = bid
        end

        # should be same as corresponding Sidekiq::Batch's jobs_count
        def total
          1
        end

        private

        attr_writer :bid
      end
      # rubocop:enable RSpec/LeakyConstantDeclaration

      def initialize
        self.bid = SecureRandom.hex(8)
        self.callbacks_stack = {}
      end

      def jobs
        return unless jobs_count.positive?
        yield
        execute_callbacks(:complete)
        execute_callbacks(:success)
      rescue self.class::JobExecutionError
        execute_callbacks(:death)
      end

      def on(event, target, options)
        callbacks_stack[event] ||= []
        callbacks_stack[event] << [target, options]
      end

      # should be same as corresponding Sidekiq::Batch::Status' total
      def jobs_count
        1
      end

      private

      attr_accessor :callbacks_stack
      attr_writer :bid

      def execute_callback(event, target, status, options)
        if target.is_a?(String)
          target        = target.split("#")
          target_class  = target[0].constantize
          target_method = target[1]
          target_class.send(target_method, status, options)
        else
          target.new.send("on_#{event}", status, options)
        end
      end

      # rubocop:disable Performance/StringIdentifierArgument
      def execute_callbacks(event)
        status = Object.const_get("Sidekiq::Batch::Status").new(bid)

        callbacks_stack[event]&.each do |target, options|
          execute_callback(event, target, status, options)
        end
      end
      # rubocop:enable Performance/StringIdentifierArgument
    end

    stub_const("Sidekiq::Batch", batch_class)
  end
end

RSpec.shared_context "callback_target_stub" do
  before do
    target_class = Class.new do
      def on_complete(_status, _options); end

      def on_success(_status, _options); end

      def on_death(_status, _options); end
    end

    stub_const("CallbackTarget", target_class)
  end
end
