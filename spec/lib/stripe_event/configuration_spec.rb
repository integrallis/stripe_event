require 'spec_helper'

RSpec.describe StripeEvent::Configuration do
  subject(:configuration) { described_class.instance }

  it 'always refers to the same instance' do
    expect(configuration).to eql(described_class.instance)
  end

  describe '#configure' do
    it 'requires a block argument' do
      expect { configuration.configure }.to raise_error(ArgumentError)
    end

    it 'yields itself to the block' do
      configuration.configure do |config|
        expect(configuration).to eq(config)
      end
    end
  end
end
