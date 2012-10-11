require 'spec_helper'

describe StripeEvent do
  let(:event_type) { StripeEvent::TYPE_LIST.sample }

  context "subscribing" do
    it "registers a subscriber" do
      subscriber = StripeEvent.subscribe(event_type) { |e| }
      subscribers_for_type(event_type).should == [subscriber]
    end

    it "registers subscribers within a parent block" do
      StripeEvent.setup do
        subscribe('invoice.payment_succeeded') { |e| }
      end
      subscribers_for_type('invoice.payment_succeeded').should_not be_empty
    end
  end

  context "publishing" do
    let(:event) { Hash[:type => event_type] }

    it "passes only the event object to the subscribed block" do
      expect { |block|
        StripeEvent.subscribe(event_type, &block)
        StripeEvent.publish(event)
      }.to yield_with_args(event)
    end
  end

  context "retrieving" do
    let(:params) { Hash[:id => '1'] }

    it "uses Stripe::Event as the default event retriever" do
      Stripe::Event.should_receive(:retrieve).with('1')
      StripeEvent.event_retriever.call(params)
    end

    it "allows setting an event_retriever" do
      StripeEvent.event_retriever = Proc.new { |*args| args }
      StripeEvent.event_retriever.call(params).should == [params]
    end
  end
end
