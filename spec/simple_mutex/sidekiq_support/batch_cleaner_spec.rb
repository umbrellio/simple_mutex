# frozen_string_literal: true

RSpec.describe SimpleMutex::SidekiqSupport::BatchCleaner do
  let(:redis) { SimpleMutex.redis }

  let(:present_batch_bid) { SecureRandom.hex(8) }

  let(:lock_for_present_batch_key) { "lock_key_1" }

  let(:lock_for_present_batch_value) do
    JSON.generate(
      "signature"  => SecureRandom.hex(8),
      "created_at" => Time.now.to_s,
      "payload"    => {
        "type"       => "Batch",
        "started_at" => Time.now.to_s,
        "bid"        => present_batch_bid,
      },
    )
  end

  let(:lock_for_non_existent_batch_key) { "lock_key_2" }

  let(:lock_for_non_existent_batch_value) do
    JSON.generate(
      "signature"  => SecureRandom.hex(8),
      "created_at" => Time.now.to_s,
      "payload"    => {
        "type"       => "Batch",
        "started_at" => Time.now.to_s,
        "bid"        => "another_bid_123123",
      },
    )
  end

  let(:unrelated_record_key) { "lock_key_3" }

  let(:unrelated_record_value) { "not_a_valid_json[]{}" }

  include_context "sidekiq pro defined"

  # rubocop:disable Style/OpenStructUse
  before do
    batch_set_class = Class.new(Array)

    stub_const("Sidekiq::BatchSet", batch_set_class)

    allow(Sidekiq::BatchSet).to receive(:new).and_return(
      Sidekiq::BatchSet.new([OpenStruct.new(bid: present_batch_bid)]),
    )
  end
  # rubocop:enable Style/OpenStructUse

  describe "#unlock_dead_batches" do
    around do |example|
      Timecop.freeze(Time.now) do
        redis.set(
          lock_for_present_batch_key,
          lock_for_present_batch_value,
          nx: true, px: 60 * 1000,
        )
        redis.set(
          lock_for_non_existent_batch_key,
          lock_for_non_existent_batch_value,
          nx: true, px: 60 * 1000,
        )
        redis.set(
          unrelated_record_key,
          unrelated_record_value,
          nx: true, px: 60 * 1000,
        )

        example.run
      end

      redis.del(lock_for_present_batch_key)
      redis.del(lock_for_non_existent_batch_key)
      redis.del(unrelated_record_key)
    end

    it "removes lock for dead batches" do
      described_class.unlock_dead_batches

      expect(redis.get(lock_for_present_batch_key))
        .not_to eq(nil)
      expect(redis.get(lock_for_non_existent_batch_key))
        .to eq(nil)
      expect(redis.get(unrelated_record_key))
        .not_to eq(nil)
    end

    describe "logging" do
      include_context "logging"

      context "redis del returns positive number as intended (means deletion succeeded)" do
        it "logs everything with info" do
          described_class.unlock_dead_batches

          expected_messages = [
            [:info, "START #{described_class.name}"],
            [:info, "Trying to delete row with key <#{lock_for_non_existent_batch_key.inspect}> " \
                    "and value <#{lock_for_non_existent_batch_value.inspect}>. " \
                    "MULTI returned value <[1]>."],
            [:info, "END #{described_class.name}"],
          ]

          expect(logger_messages).to eq(expected_messages)
        end
      end

      # should not happen, but we encountered this few times long time ago,
      # key was also not deleted, so we decided to log this
      context "redis del returns nil" do
        # mocking methods inside multi results in unpredictable results
        before do
          allow(redis).to receive(:multi).and_return([])
        end

        it "logs start and with info, deletion attempt with error" do
          described_class.unlock_dead_batches

          expected_messages = [
            [:info, "START #{described_class.name}"],
            [:error, "Trying to delete row with key <#{lock_for_non_existent_batch_key.inspect}> " \
                     "and value <#{lock_for_non_existent_batch_value.inspect}>. " \
                     "MULTI returned value <[]>."],
            [:error, "Trying to delete row with key <#{lock_for_non_existent_batch_key.inspect}> " \
                     "and value <#{lock_for_non_existent_batch_value.inspect}>. " \
                     "MULTI returned value <[]>."],
            [:error, "Trying to delete row with key <#{lock_for_non_existent_batch_key.inspect}> " \
                     "and value <#{lock_for_non_existent_batch_value.inspect}>. " \
                     "MULTI returned value <[]>."],
            [:info, "END #{described_class.name}"],
          ]

          expect(logger_messages).to eq(expected_messages)
        end
      end
    end
  end
end
