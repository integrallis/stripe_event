require 'spec_helper'

describe StripeEvent do
  let(:event_type) { StripeEvent::TYPE_LIST.sample }

  it "backend defaults to AS::Notifications" do
    expect(described_class.backend).to eq ActiveSupport::Notifications
  end

  it "registers a subscriber" do
    subscriber = described_class.subscribe(event_type) { |e| }
    subscribers = subscribers_for_type(event_type)
    expect(subscribers).to eq [subscriber]
  end

  it "registers subscribers within a parent block" do
    described_class.setup do
      subscribe('invoice.payment_succeeded') { |e| }
    end
    subscribers = subscribers_for_type('invoice.payment_succeeded')
    expect(subscribers).to_not be_empty
  end

  it "passes only the event object to the subscribed block" do
    event = { :type => event_type }

    expect { |block|
      described_class.subscribe(event_type, &block)
      described_class.publish(event)
    }.to yield_with_args(event)
  end

  it "uses Stripe::Event as the default event retriever" do
    Stripe::Event.should_receive(:retrieve).with('1')
    described_class.event_retriever.call(:id => '1')
  end

  it "allows setting an event_retriever" do
    params = { :id => '1' }

    described_class.event_retriever = Proc.new { |arg| arg }
    event = described_class.event_retriever.call(params)
    expect(event).to eq params
  end

  it "allows using an event_retriever that utilizes Stripe::Event.construct_from" do
    params = { 'id' => '1', 'type' => 'charge.succeeded' }

    described_class.event_retriever = Proc.new { |params| Stripe::Event.construct_from(params) }
    described_class.setup do
      subscribe 'charge.succeeded' do |event|
        raise "this code should be run"
      end
    end
    event = described_class.event_retriever.call(params)
    expect {described_class.publish(event)}.to raise_error(StandardError)
  end
end
