# frozen_string_literal: true

RSpec.describe SimpleMutex::BatchCleaner do
  let(:redis)    { SimpleMutex.redis }
  let(:lock_key) { "batch_lock_key" }
  let(:bid)      { SecureRandom.hex(8) }

  before do
    allow(SimpleMutex).to receive(:sidekiq_pro_installed?).and_return(true)

    batch_set_class = Class.new(Array) do
    end

    stub_const("Sidekiq::BatchSet", batch_set_class)

    allow(Sidekiq::BatchSet).to receive(:new).and_return(
      Sidekiq::BatchSet.new([OpenStruct.new(bid: bid)]),
    )
  end

  describe "#unlock_dead_batches" do
    around do |example|
      Timecop.freeze(Time.now) do
        redis.set(
          "lock_key_1",
          JSON.generate(
            "signature"  => SecureRandom.hex(8),
            "created_at" => Time.now.to_s,
            "payload"    => {
              "type"       => "Batch",
              "started_at" => Time.now.to_s,
              "bid"        => bid,
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
              "type"       => "Batch",
              "started_at" => Time.now.to_s,
              "bid"        => "anotherbid123123",
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

    it "removes lock for dead batches" do
      described_class.unlock_dead_batches

      expect(redis.get("lock_key_1")).not_to eq(nil)
      expect(redis.get("lock_key_2")).to eq(nil)
    end
  end
end
