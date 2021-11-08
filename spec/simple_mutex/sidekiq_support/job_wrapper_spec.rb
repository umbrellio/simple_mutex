# frozen_string_literal: true

require "sidekiq/worker"

RSpec.describe SimpleMutex::SidekiqSupport::JobWrapper do
  let(:redis)             { SimpleMutex.redis }
  let(:jid)               { "08e6a309cf7c46dc0178c53f" }
  let(:in_job_test_suite) { -> {} }

  let(:job) do
    klass = Class.new do
      def run_tests; end
    end

    klass.send(:include, Sidekiq::Worker)
    stub_const("TestJob", klass)

    instance = TestJob.new

    allow(instance).to receive(:jid).and_return(jid)
    allow(instance).to receive(:run_tests) do
      in_job_test_suite.call
    end

    instance
  end

  before do
    Timecop.freeze(Time.now)
  end

  describe "#with_redlock" do
    let(:params)   { [1, nil, "qwe"] }
    let(:lock_key) { "TestJob<[1,null,\"qwe\"]>" }

    let(:in_job_test_suite) do
      lambda do
        data = JSON.parse(redis.get(lock_key))

        expect(data["payload"]).to eq(
          "type"       => "Job",
          "started_at" => Time.now.to_s,
          "jid"        => jid,
        )
      end
    end

    after do
      redis.del(lock_key)
    end

    it "creates mutex that exists while block is executed" do
      described_class.new(
        job,
        params:           params,
        lock_with_params: true,
        expires_in:       60,
      ).with_redlock do
        job.run_tests
      end

      expect(redis.get(lock_key)).to eq(nil)
    end

    context "lock_key_override" do
      let(:lock_key) { "overriden" }

      it "created mutex with overriden lock_key" do
        described_class.new(
          job,
          params:     params,
          lock_key:   lock_key,
          expires_in: 60,
        ).with_redlock do
          job.run_tests
        end

        expect(redis.get(lock_key)).to eq(nil)
      end
    end
  end
end
