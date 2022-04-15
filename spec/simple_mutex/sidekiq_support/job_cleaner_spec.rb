# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe SimpleMutex::SidekiqSupport::JobCleaner do
  let(:redis) { SimpleMutex.redis }

  let(:present_job_jid) { SecureRandom.hex(8) }

  let(:lock_for_present_job_key) { "lock_key_1" }

  let(:lock_for_present_job_value) do
    JSON.generate(
      "signature"  => SecureRandom.hex(8),
      "created_at" => Time.now.to_s,
      "payload"    => {
        "type"       => "Job",
        "started_at" => Time.now.to_s,
        "jid"        => present_job_jid,
      },
    )
  end

  let(:lock_for_non_existent_job_key) { "lock_key_2" }

  let(:lock_for_non_existent_job_value) do
    JSON.generate(
      "signature"  => SecureRandom.hex(8),
      "created_at" => Time.now.to_s,
      "payload"    => {
        "type"       => "Job",
        "started_at" => Time.now.to_s,
        "jid"        => "another_jid_123123",
      },
    )
  end

  let(:unrelated_record_key) { "lock_key_3" }

  let(:unrelated_record_value) { "not_a_valid_json[]{}" }

  before do
    workers_instance = instance_double(Sidekiq::Workers)

    allow(workers_instance).to receive(:map)
      .and_yield(1, 1, "payload" => { "jid" => present_job_jid })

    allow(Sidekiq::Workers).to receive(:new).and_return(workers_instance)
  end

  describe "#unlock_dead_jobs" do
    around do |example|
      Timecop.freeze(Time.now) do
        redis.set(
          lock_for_present_job_key,
          lock_for_present_job_value,
          nx: true, px: 60 * 1000,
        )
        redis.set(
          lock_for_non_existent_job_key,
          lock_for_non_existent_job_value,
          nx: true, px: 60 * 1000,
        )
        redis.set(
          unrelated_record_key,
          unrelated_record_value,
          nx: true, px: 60 * 1000,
        )

        example.run
      end

      redis.del(lock_for_present_job_key)
      redis.del(lock_for_non_existent_job_key)
      redis.del(unrelated_record_key)
    end

    it "removes lock for dead jobs" do
      described_class.unlock_dead_jobs

      expect(redis.get(lock_for_present_job_key))
        .not_to eq(nil)
      expect(redis.get(lock_for_non_existent_job_key))
        .to eq(nil)
      expect(redis.get(unrelated_record_key))
        .not_to eq(nil)
    end

    describe "logging" do
      include_context "logging"

      context "redis del returns positive number as intended (means deletion succeeded)" do
        it "logs everything with info" do
          described_class.unlock_dead_jobs

          expected_messages = [
            [:info, "START #{described_class.name}"],
            [:info, "Trying to delete row with key <#{lock_for_non_existent_job_key.inspect}> "\
                    "and value <#{lock_for_non_existent_job_value.inspect}>. "\
                    "MULTI returned value <[1]>."],
            [:info, "END #{described_class.name}"],
          ]

          expect(logger_messages).to eq(expected_messages)
        end
      end

      # should not happen, but we encountered this few times long time ago,
      # key was also not deleted, so we decided to log this
      context "redis del returns nil" do
        before do
          allow(redis).to receive(:del).and_return(nil)
        end

        it "logs start and with info, deletion attempt with error" do
          described_class.unlock_dead_jobs

          expected_messages = [
            [:info, "START #{described_class.name}"],
            [:error, "Trying to delete row with key <#{lock_for_non_existent_job_key.inspect}> "\
                     "and value <#{lock_for_non_existent_job_value.inspect}>. "\
                     "MULTI returned value <[]>."],
            [:error, "Trying to delete row with key <#{lock_for_non_existent_job_key.inspect}> "\
                     "and value <#{lock_for_non_existent_job_value.inspect}>. "\
                     "MULTI returned value <[]>."],
            [:error, "Trying to delete row with key <#{lock_for_non_existent_job_key.inspect}> "\
                     "and value <#{lock_for_non_existent_job_value.inspect}>. "\
                     "MULTI returned value <[]>."],
            [:info, "END #{described_class.name}"],
          ]

          expect(logger_messages).to eq(expected_messages)
        end
      end
    end
  end
end
