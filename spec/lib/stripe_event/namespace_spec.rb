require 'spec_helper'

RSpec.describe StripeEvent::Namespace do
  let(:namespace) { described_class.new('stripe_event', '.') }

  describe '#call' do
    it 'prepends the namespace to a given string' do
      expect(namespace.call('foo.bar')).to eq('stripe_event.foo.bar')
    end

    it 'returns the namespace given no arguments' do
      expect(namespace.call).to eq('stripe_event.')
    end
  end

  describe '#to_regexp' do
    it 'matches namespaced strings' do
      expect(namespace.to_regexp('foo.bar')).to match(namespace.call('foo.bar'))
    end

    it 'matches all namespaced strings given no arguments' do
      expect(namespace.to_regexp).to match(namespace.call('foo.bar'))
    end
  end
end
