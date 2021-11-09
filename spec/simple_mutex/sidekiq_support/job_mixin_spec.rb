# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe SimpleMutex::SidekiqSupport::JobMixin do
  let(:wrapper_class) { SimpleMutex::SidekiqSupport::JobWrapper }
  let(:args)          { %w[arg1 arg2] }

  let(:application_job_class) do
    Class.new do
      include Sidekiq::Worker
      include SimpleMutex::SidekiqSupport::JobMixin

      class << self
        def inherited(job_class)
          job_class.prepend(
            Module.new do
              def perform(*args)
                with_redlock(args) { super }
              end

              # stubbing job id
              def jid
                1
              end
            end,
          )
        end
      end
    end
  end

  before do
    allow(wrapper_class).to receive(:new).and_call_original
  end

  context "locking! only" do
    let(:job_class) do
      Class.new(application_job_class) do
        locking!

        def perform(_arg1, _arg2); end
      end
    end

    let(:job) { job_class.new }

    before do
      allow(job_class).to receive(:name).and_return("TestJob")
    end

    it "calls job wrapper without timeout and without lock_with_params" do
      expect(wrapper_class).to receive(:new).with(
        job, params: args, lock_with_params: false
      )
      job.perform(*args)
    end
  end

  context "locking! and lock_with_params!" do
    let(:job_class) do
      Class.new(application_job_class) do
        locking!
        lock_with_params!

        def perform(_arg1, _arg2); end
      end
    end

    let(:job) { job_class.new }

    before do
      allow(job_class).to receive(:name).and_return("TestJob")
    end

    it "calls job wrapper with lock_with_params" do
      expect(wrapper_class).to receive(:new).with(
        job, params: args, lock_with_params: true
      )

      job.perform(*args)
    end
  end

  context "locking! and set_job_timeout" do
    let(:job_class) do
      Class.new(application_job_class) do
        locking!
        set_job_timeout 3600

        def perform(_arg1, _arg2); end
      end
    end

    let(:job) { job_class.new }

    before do
      allow(job_class).to receive(:name).and_return("TestJob")
    end

    it "calls job wrapper with timeout" do
      expect(wrapper_class).to receive(:new).with(
        job, params: args, lock_with_params: false, expires_in: 3600
      )

      job.perform(*args)
    end
  end

  describe "error processing" do
    before do
      allow_any_instance_of(SimpleMutex::Mutex).to receive(:lock!) do
        raise SimpleMutex::Mutex::LockError.new("failed to acquire lock <TestJob>.", "TestJob")
      end
    end

    context "no skip_locking_error" do
      let(:job_class) do
        Class.new(application_job_class) do
          locking!

          def perform(_arg1, _arg2); end
        end
      end

      let(:job) { job_class.new }

      before do
        allow(job_class).to receive(:name).and_return("TestJob")
      end

      it "does not suppress locking errorr" do
        expect { job.perform(*args) }.to raise_error(SimpleMutex::Mutex::LockError)
      end
    end

    context "skip_locking_error!" do
      let(:job_class) do
        Class.new(application_job_class) do
          locking!
          skip_locking_error!

          def perform(_arg1, _arg2); end
        end
      end

      let(:job) { job_class.new }

      before do
        allow(job_class).to receive(:name).and_return("TestJob")
      end

      it "suppresses error" do
        expect { job.perform(*args) }.not_to raise_error
      end
    end
  end
end
