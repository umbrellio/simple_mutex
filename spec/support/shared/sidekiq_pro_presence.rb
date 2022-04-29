# frozen_string_literal: true

RSpec.shared_context "sidekiq pro defined" do
  before do
    allow(Object).to receive(:const_defined?).and_call_original
    allow(Object).to receive(:const_defined?).with(:"Sidekiq::Pro::VERSION").and_return(true)
  end
end

RSpec.shared_context "sidekiq pro not defined" do
  before do
    allow(Object).to receive(:const_defined?).and_call_original
    allow(Object).to receive(:const_defined?).with(:"Sidekiq::Pro::VERSION").and_return(false)
  end
end
