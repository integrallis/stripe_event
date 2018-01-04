require 'spec_helper'

RSpec.describe StripeEvent::NotificationAdapter do
  subject(:adapter) { described_class.new(subscriber) }

  let(:subscriber) { proc {} }

  describe '.call' do
    before do
      allow(described_class).to receive(:new)
      described_class.call(subscriber)
    end

    it { expect(described_class).to have_received(:new).with(subscriber) }
  end

  describe '#call' do
    before do
      allow(subscriber).to receive(:call).with(:last)
      adapter.call(:first, :last)
    end

    it 'calls the subscriber with the last argument' do
      expect(subscriber).to have_received(:call).with(:last)
    end
  end
end
