require 'spec_helper'

describe StripeEvent do
  before { StripeEvent.clear_subscribers! }
  
  context "configuration" do
    it "yields itself to the block" do
      StripeEvent.configure do |config|
        config.should == StripeEvent
      end
    end
    
    it "should return itself" do
      value = StripeEvent.configure { |c| }
      value.should == StripeEvent
    end
  end
  
  context "subscribing" do
    let(:event_type) { 'charge.failed' }
    
    it "should register a subscriber" do
      subscriber = StripeEvent.subscribe(event_type) { }
      StripeEvent.subscribers(event_type).should == [subscriber]
    end
    
    it "should require a valid event type" do
      expect {
        StripeEvent.subscribe('fake.event_type') { }
      }.to raise_error(StripeEvent::InvalidEventType)
    end
    
    it "should clear all subscribers" do
      StripeEvent.subscribe(event_type) { }
      StripeEvent.subscribe(event_type) { }
      StripeEvent.clear_subscribers!
      StripeEvent.subscribers(event_type).should be_empty
    end
  end
  
  context "publishing" do
    let(:event_type) { 'transfer.created' }
    let(:event) { double("event", :type => event_type) }
    
    it "should only pass the event to the subscribed block" do
      expect { |block|
        StripeEvent.subscribe(event_type, &block)
        StripeEvent.publish(event)
      }.to yield_with_args(event)
    end
  end
end
