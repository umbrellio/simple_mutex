# frozen_string_literal: true

RSpec.describe SimpleMutex::Mutex do
  let(:redis_instance) { instance_double(Redis) }
  let(:lock_key) { "test_lock_key" }

  let(:options) do
    { expire: 60, payload: ["test_payload"] }
  end

  let(:redis) { SimpleMutex.redis }

  around do |example|
    redis.del(lock_key)
    example.run
    redis.del(lock_key)
  end

  describe "class methods" do
    describe "#lock" do
      it "creates instance with expected args" do
        allow(described_class).to receive(:new).and_call_original
        expect(described_class).to receive(:new).with(lock_key, **options)
        described_class.lock(lock_key, **options)
      end

      it "calls corresponding instance method" do
        instance = described_class.new(**options)
        allow(described_class).to receive(:new).with(lock_key, **options).and_return(instance)
        expect(instance).to receive("lock").with(no_args)
        described_class.lock(lock_key, **options)
      end
    end

    describe "#lock!" do
      it "creates instance with expected args" do
        allow(described_class).to receive(:new).and_call_original
        expect(described_class).to receive(:new).with(lock_key, **options)
        described_class.lock!(lock_key, options)
      end

      it "calls corresponding instance method" do
        instance = described_class.new(**options)
        allow(described_class).to receive(:new).with(lock_key, **options).and_return(instance)
        expect(instance).to receive("lock!").with(no_args)
        described_class.lock!(lock_key, options)
      end
    end

    describe "#with_lock" do
      let(:block_proc) { proc { nil } }

      it "creates instance with expected args" do
        allow(described_class).to receive(:new).and_call_original
        expect(described_class).to receive(:new).with(lock_key, **options)

        described_class.with_lock(lock_key, **options, &block_proc)
      end

      it "calls corresponding instance method" do
        instance = described_class.new(**options)

        allow(described_class).to receive(:new).with(lock_key, **options).and_return(instance)

        expect(instance).to receive(:with_lock) do |&block|
          expect(block_proc).to be(block)
        end

        described_class.with_lock(lock_key, **options, &block_proc)
      end
    end

    describe "unlocking" do
      let(:invalid_lock_key)  { "invalid_lock_key" }
      let(:valid_signature)   { "valid_signature" }
      let(:invalid_signature) { "invalid_signature" }

      let(:data) do
        JSON.generate(
          "signature"  => valid_signature,
          "created_at" => Time.now.to_s,
          "payload"    => nil,
        )
      end

      around do |example|
        redis.set(lock_key, data, nx: true, px: 60 * 1000)
        example.run
        redis.del(lock_key)
      end

      describe "#unlock" do
        context "when called with existing lock_key, valid signature, no force" do
          it "removes key, returns true" do
            result = described_class.unlock(lock_key, signature: valid_signature, force: false)
            expect(result).to eq(true)
            expect(redis.get(lock_key)).to eq(nil)
          end
        end

        context "when called with existing lock_key, ivalid signature, no force" do
          it "does not delete key, returns false" do
            result = described_class.unlock(lock_key, signature: invalid_signature, force: false)
            expect(result).to eq(false)
            expect(redis.get(lock_key)).not_to eq(nil)
          end
        end

        context "when called with existing lock_key" do
          it "removes key, returns true" do
            result = described_class.unlock(lock_key, signature: invalid_signature, force: true)
            expect(result).to eq(true)
            expect(redis.get(lock_key)).to eq(nil)
          end
        end

        context "when called with non_existing lock_key" do
          it "does not delete key, returns false" do
            result = described_class.unlock(invalid_lock_key, force: true)
            expect(result).to eq(false)
            expect(redis.get(lock_key)).not_to eq(nil)
          end
        end
      end

      describe "#unlock!" do
        context "when called with existing lock_key, valid signature, no force" do
          it "removes key" do
            described_class.unlock(lock_key, signature: valid_signature, force: false)
            expect(redis.get(lock_key)).to eq(nil)
          end
        end

        context "when called with existing lock_key, ivalid signature, no force" do
          it "raises error" do
            expect do
              described_class.unlock!(lock_key, signature: invalid_signature, force: false)
            end.to(
              raise_error(SimpleMutex::Mutex::UnlockError)
                .with_message("signature mismatch for lock key <#{lock_key}>."),
            )
          end
        end

        context "when called with existing lock_key, ivalid signature, force" do
          it "removes key" do
            described_class.unlock!(lock_key, signature: invalid_signature, force: true)
            expect(redis.get(lock_key)).to eq(nil)
          end
        end

        context "when called with non-existing lock_key" do
          it "raises error" do
            expect do
              described_class.unlock!(invalid_lock_key, force: true)
            end.to(
              raise_error(SimpleMutex::Mutex::UnlockError)
                .with_message("lock not found for lock key <#{invalid_lock_key}>."),
            )
          end
        end
      end
    end
  end

  describe "instance methods" do
    let(:options) { super().merge(signature: "test_signature") }

    let(:instance) do
      described_class.new(lock_key, options)
    end

    let(:expected_data) do
      JSON.generate(
        "signature"  => options[:signature],
        "created_at" => Time.now.to_s,
        "payload"    => options[:payload],
      )
    end

    before do
      Timecop.freeze(Time.now)
    end

    describe "#lock" do
      context "when lock does not exist" do
        it "creates lock, returns true" do
          result = instance.lock
          expect(result).to eq(true)
          expect(redis.get(lock_key)).to eq(expected_data)
        end
      end

      context "when lock aready exists" do
        before do
          redis.set(lock_key, "old_data", nx: true, px: 60 * 1000)
        end

        it "does not overwrite existing lock, returns false" do
          result = instance.lock
          expect(result).to eq(false)
          expect(redis.get(lock_key)).to eq("old_data")
        end
      end
    end

    describe "#lock!" do
      context "when lock does not exist" do
        it "creates lock" do
          instance.lock!
          expect(redis.get(lock_key)).to eq(expected_data)
        end
      end

      context "when lock aready exists" do
        before do
          redis.set(lock_key, "old_data", nx: true, px: 60 * 1000)
        end

        it "raises error" do
          expect do
            instance.lock!
          end.to(
            raise_error(described_class::LockError)
              .with_message("failed to acquire lock <#{lock_key}>."),
          )
        end
      end
    end

    describe "#with_lock" do
      it "locks during execution of block" do
        instance.with_lock do
          expect(redis.get(lock_key)).to eq(expected_data)
        end
        expect(redis.get(lock_key)).to eq(nil)
      end
    end
  end
end
