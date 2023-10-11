# frozen_string_literal: true

RSpec.describe SimpleMutex::Helper do
  let(:redis)     { SimpleMutex.redis }
  let(:jid)       { SecureRandom.hex(8) }
  let(:bid)       { SecureRandom.hex(8) }
  let(:signature) { SecureRandom.hex(8) }

  let(:data_1) do
    {
      "signature"  => signature,
      "created_at" => Time.now.to_s,
      "payload"    => {
        "type"       => "Job",
        "started_at" => Time.now.to_s,
        "jid"        => jid,
      },
    }
  end

  let(:data_2) do
    {
      "signature"  => signature,
      "created_at" => Time.now.to_s,
      "payload"    => {
        "type"       => "Batch",
        "started_at" => Time.now.to_s,
        "jid"        => "bid",
      },
    }
  end

  let(:data_3) do
    {
      "signature"  => signature,
      "created_at" => Time.now.to_s,
      "payload"    => nil,
    }
  end

  around do |example|
    Timecop.freeze(Time.now) do
      redis.set(
        "lock_key_1",
        JSON.generate(data_1),
        nx: true,
        px: 60 * 1000,
      )

      redis.set(
        "lock_key_2",
        JSON.generate(data_2),
        nx: true,
        px: 60 * 1000,
      )

      redis.set(
        "lock_key_3",
        JSON.generate(data_3),
        nx: true,
        px: 60 * 1000,
      )

      redis.set(
        "lock_key_4",
        "not_a_valid_json",
        nx: true,
        px: 60 * 1000,
      )

      example.run
    end

    redis.del("lock_key_1")
    redis.del("lock_key_2")
    redis.del("lock_key_3")
    redis.del("lock_key_4")
  end

  describe "#get" do
    it "getting lock" do
      expect(described_class.get("lock_key_1")).to eq(
        key: "lock_key_1",
        value: data_1,
      )
    end
  end

  describe "#list" do
    context "when mode: :default" do
      it "return job and batch locks" do
        list = described_class.list(mode: :default)

        expect(list).to(
          contain_exactly(
            { key: "lock_key_1", value: data_1 },
            { key: "lock_key_2", value: data_2 },
          ),
        )
      end
    end

    context "when mode: :all" do
      it "return all locks including manual" do
        list = described_class.list(mode: :all)

        expect(list).to(
          contain_exactly(
            { key: "lock_key_1", value: data_1 },
            { key: "lock_key_2", value: data_2 },
            { key: "lock_key_3", value: data_3 },
            { key: "lock_key_4", value: "not_a_valid_json" },
          ),
        )
      end
    end

    context "when mode: :job" do
      it "return job locks" do
        list = described_class.list(mode: :job)

        expect(list).to(
          contain_exactly(
            { key: "lock_key_1", value: data_1 },
          ),
        )
      end
    end

    context "when mode: :batch" do
      it "return batch locks" do
        list = described_class.list(mode: :batch)

        expect(list).to(
          contain_exactly(
            { key: "lock_key_2", value: data_2 },
          ),
        )
      end
    end

    context "when called with unknown mode" do
      it "raises error" do
        expect { described_class.list(mode: :not_a_valid_mode) }.to(
          raise_error(
            SimpleMutex::Error, "invalid mode ( only [:job, :batch, :default, :all] allowed)."
          ),
        )
      end
    end
  end
end
