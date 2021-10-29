# frozen_string_literal: true

RSpec.describe SimpleMutex::SidekiqSupport::Batch do
  let(:redis) { SimpleMutex.redis }

  include_context "batch_stub"
  include_context "callback_target_stub"

  before do
    allow(SimpleMutex).to receive(:sidekiq_pro_installed?).and_return(true)
  end

  describe "" do
    let(:lock_key) { "batch_lock_key" }

    let(:batch) do
      batch = SimpleMutex::SidekiqSupport::Batch.new(
        lock_key: lock_key,
        expires_in: 60 * 1000,
      )

      batch.description = "TestBatch"
      batch.on(:complete, CallbackTarget, {})
      batch.on(:success,  CallbackTarget, {})
      batch.on(:death,    CallbackTarget, {})
      batch
    end

    let(:expected_payload) do
      { "type"       => "Batch",
        "started_at" => Time.now.to_s,
        "bid"        => batch.bid }
    end

    around do |example|
      Timecop.freeze(Time.now) do
        example.run
      end
      redis.del(lock_key)
    end

    context "when jobs execute succesfully" do
      it "runs success and complete callbacks" do
        expect_any_instance_of(CallbackTarget).to receive(:on_complete)
        expect_any_instance_of(CallbackTarget).to receive(:on_success)
        expect_any_instance_of(CallbackTarget).not_to receive(:on_death)
        batch.jobs do
          expect(JSON.parse(redis.get(lock_key))["payload"]).to eq(expected_payload)
        end
        expect(redis.get(lock_key)).to eq(nil)
      end
    end

    context "when jobs fail" do
      it "runs death callback" do
        expect_any_instance_of(CallbackTarget).not_to receive(:on_complete)
        expect_any_instance_of(CallbackTarget).not_to receive(:on_success)
        expect_any_instance_of(CallbackTarget).to receive(:on_death)
        batch.jobs do
          expect(JSON.parse(redis.get(lock_key))["payload"]).to eq(expected_payload)
          raise StandardError
        end
        expect(redis.get(lock_key)).to eq(nil)
      end
    end

    context "when no batch started withoud jobs" do
      before do
        allow_any_instance_of(Sidekiq::Batch).to receive(:jobs_count).and_return(0)
        allow_any_instance_of(Sidekiq::Batch::Status).to receive(:total).and_return(0)
      end

      it "removes key manually" do
        expect_any_instance_of(CallbackTarget).not_to receive(:on_complete)
        expect_any_instance_of(CallbackTarget).not_to receive(:on_success)
        expect_any_instance_of(CallbackTarget).not_to receive(:on_death)

        expect_any_instance_of(SimpleMutex::SidekiqSupport::BatchCallbacks)
          .not_to receive(:on_success)
        expect_any_instance_of(SimpleMutex::SidekiqSupport::BatchCallbacks)
          .not_to receive(:on_death)
        begin
          batch.jobs do
            expect(JSON.parse(redis.get(lock_key))["payload"]).to eq(expected_payload)
            nil
          end
        rescue
          nil
        end
        expect(redis.get(lock_key)).to eq(nil)
      end

      it "raises error" do
        expect do
          batch.jobs { nil }
        end.to raise_error(SimpleMutex::SidekiqSupport::Batch::Error)
      end
    end
  end
end
