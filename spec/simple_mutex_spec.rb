# frozen_string_literal: true

RSpec.describe SimpleMutex do
  it "has a version number" do
    expect(SimpleMutex::VERSION).not_to be nil
  end

  describe "#redis_check!" do
    context "when no redis provided" do
      around do |example|
        redis = described_class.redis

        described_class.redis = nil

        example.run

        described_class.redis = redis
      end

      it "raises error" do
        expect do
          described_class.redis_check!
        end.to raise_error(
          SimpleMutex::Error,
          "You should set SimpleMutex.redis before using any functions of this gem.",
        )
      end
    end

    context "when redis provided" do
      it "does not raise error" do
        expect do
          described_class.redis_check!
        end.not_to raise_error
      end
    end
  end

  describe "#sidekiq_pro_check!" do
    context "no sidekiq pro" do
      before do
        allow(Object).to receive(:const_defined?).with(:"Sidekiq::Pro::VERSION").and_return(false)
      end

      it "raises error" do
        expect do
          described_class.sidekiq_pro_check!
        end.to raise_error(
          SimpleMutex::Error,
          "Batch related functionality requires Sidekiq Pro to be installed.",
        )
      end
    end

    context "sidekiq pro installed" do
      before do
        allow(Object).to receive(:const_defined?).with(:"Sidekiq::Pro::VERSION").and_return(true)
      end

      it "does not raise error" do
        expect do
          described_class.sidekiq_pro_check!
        end.not_to raise_error
      end
    end
  end
end
