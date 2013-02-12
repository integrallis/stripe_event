require 'spec_helper'

describe StripeEvent do
  let(:event_type) { StripeEvent::TYPE_LIST.sample }

  it "backend defaults to AS::Notifications" do
    expect(StripeEvent.backend).to eq ActiveSupport::Notifications
  end

  it "registers a subscriber" do
    subscriber = StripeEvent.subscribe(event_type) { |e| }
    subscribers = subscribers_for_type(event_type)
    expect(subscribers).to eq [subscriber]
  end

  it "registers subscribers within a parent block" do
    StripeEvent.setup do
      subscribe('invoice.payment_succeeded') { |e| }
    end
    subscribers = subscribers_for_type('invoice.payment_succeeded')
    expect(subscribers).to_not be_empty
  end

  it "passes only the event object to the subscribed block" do
    event = { :type => event_type }

    expect { |block|
      StripeEvent.subscribe(event_type, &block)
      StripeEvent.publish(event)
    }.to yield_with_args(event)
  end

  it "uses Stripe::Event as the default event retriever" do
    Stripe::Event.should_receive(:retrieve).with('1')
    StripeEvent.event_retriever.call(:id => '1')
  end

  it "allows setting an event_retriever" do
    params = { :id => '1' }

    StripeEvent.event_retriever = Proc.new { |arg| arg }
    event = StripeEvent.event_retriever.call(params)
    expect(event).to eq params
  end
end
