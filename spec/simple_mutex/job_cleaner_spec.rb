# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe SimpleMutex::JobCleaner do
  let(:redis)    { SimpleMutex.redis }
  let(:lock_key) { "batch_lock_key" }
  let(:jid)      { SecureRandom.hex(8) }

  before do
    workers_instance = instance_double(Sidekiq::Workers)

    allow(workers_instance).to receive(:map).and_yield(1, 1, "payload" => { "jid" => jid })

    allow(Sidekiq::Workers).to receive(:new).and_return(workers_instance)
  end

  describe "#unlock_dead_jobs" do
    around do |example|
      Timecop.freeze(Time.now) do
        redis.set(
          "lock_key_1",
          JSON.generate(
            "signature"  => SecureRandom.hex(8),
            "created_at" => Time.now.to_s,
            "payload"    => {
              "type"       => "Job",
              "started_at" => Time.now.to_s,
              "jid"        => jid,
            },
          ),
          nx: true,
          px: 60 * 1000,
        )

        redis.set(
          "lock_key_2",
          JSON.generate(
            "signature"  => SecureRandom.hex(8),
            "created_at" => Time.now.to_s,
            "payload"    => {
              "type"       => "Job",
              "started_at" => Time.now.to_s,
              "jid"        => "anotherjid123123",
            },
          ),
          nx: true,
          px: 60 * 1000,
        )
        example.run
      end

      redis.del("lock_key_1")
      redis.del("lock_key_2")
    end

    it "removes lock for dead jobs" do
      described_class.unlock_dead_jobs

      expect(redis.get("lock_key_1")).not_to eq(nil)
      expect(redis.get("lock_key_2")).to eq(nil)
    end
  end
end
