require 'spec_helper'

describe StripeEvent do
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
  end
end
