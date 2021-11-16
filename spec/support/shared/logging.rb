# frozen_string_literal: true

RSpec.shared_context "logging" do
  let(:stub_logger) { instance_double(Logger) }
  let(:logger_messages) { [] }

  before do
    stub_logger = instance_double(Logger)

    allow(SimpleMutex).to receive(:logger).and_return(stub_logger)

    allow(stub_logger).to receive(:info)  { |msg| logger_messages << [:info, msg] }
    allow(stub_logger).to receive(:error) { |msg| logger_messages << [:error, msg] }
  end
end
