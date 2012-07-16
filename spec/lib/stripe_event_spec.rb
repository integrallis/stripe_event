require 'spec_helper'

describe StripeEvent do
  let(:event_type) { StripeEvent::TYPE_LIST.sample }
  
  before do
    StripeEvent.clear_subscribers!
  end
  
  context "subscribing" do
    it "should register a subscriber" do
      subscriber = StripeEvent.subscribe(event_type) { }
      StripeEvent.subscribers(event_type).should == [subscriber]
    end
    
    it "should register a subscriber for many event types" do
      picked = StripeEvent::TYPE_LIST[0..3]
      unpicked = StripeEvent::TYPE_LIST[4..-1]
      subscriber = StripeEvent.subscribe(*picked) { }
      picked.each do |type|
        StripeEvent.subscribers(type).should == [subscriber]
      end
      unpicked.each do |type|
        StripeEvent.subscribers(type).should == []
      end
    end
    
    it "should register a subscriber to all events" do
      subscriber = StripeEvent.subscribe { }
      StripeEvent::TYPE_LIST.each do |type|
        StripeEvent.subscribers(type).should == [subscriber]
      end
    end
    
    it "should require a valid event type" do
      expect {
        StripeEvent.subscribe('fake.event_type') { }
      }.to raise_error(StripeEvent::InvalidEventType)
    end
    
    it "should clear all subscribers" do
      StripeEvent.subscribe(event_type) { }
      StripeEvent.clear_subscribers!
      StripeEvent.subscribers(event_type).should be_empty
    end
  end
  
  context "publishing" do
    let(:event) { double("event", :type => event_type) }
    
    it "should only pass the event to the subscribed block" do
      expect { |block|
        StripeEvent.subscribe(event_type, &block)
        StripeEvent.publish(event)
      }.to yield_with_args(event)
    end
  end
end
