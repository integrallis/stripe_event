require 'spec_helper'

describe StripeEvent do
  let(:event_type) { StripeEvent::TYPE_LIST.sample }
  
  before do
    StripeEvent.clear_subscribers!
  end
  
  context "subscribing" do
    it "registers a subscriber" do
      subscriber = StripeEvent.subscribe(event_type) { }
      StripeEvent.subscribers(event_type).should == [subscriber]
    end
    
    it "registers subscribers within a parent block" do
      StripeEvent.setup do
        subscribe('invoice.payment_succeeded') { |e| }
      end
      StripeEvent.subscribers('invoice.payment_succeeded').should_not be_empty
    end
    
    it "registers a subscriber for many event types" do
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
    
    it "registers a subscriber to all event types" do
      subscriber = StripeEvent.subscribe { }
      StripeEvent::TYPE_LIST.each do |type|
        StripeEvent.subscribers(type).should == [subscriber]
      end
    end
    
    it "requires a valid event type" do
      expect {
        StripeEvent.subscribe('fake.event_type') { }
      }.to raise_error(StripeEvent::InvalidEventType)
    end
    
    it "clears all subscribers" do
      StripeEvent.subscribe(event_type) { }
      StripeEvent.clear_subscribers!
      StripeEvent.subscribers(event_type).should be_empty
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
    it "uses Stripe::Event as the default event retriever" do
      Stripe::Event.should_receive(:retrieve).with('1')
      StripeEvent.event_retriever.call({:id => '1'})
    end

    it "allows setting an event_retriever" do
      event = stub(:event)
      StripeEvent.event_retriever = Proc.new {|params| event }
      StripeEvent.event_retriever.call({:id => '1'}).should == event
    end
  end
end
