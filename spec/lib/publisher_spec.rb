require 'spec_helper'

describe StripeEvent::Publisher do
  let(:publisher) { StripeEvent::Publisher.new(event) }
  
  let(:event) { Hash[:type => event_type] }
  let(:event_type) { StripeEvent::TYPE_LIST.sample }
  
  it "instruments the event" do
    ActiveSupport::Notifications.should_receive(:instrument).with(event_type, :event => event)
    publisher.instrument
  end
  
  describe "#type" do
    it "detemines the type of event given" do
      publisher.type.should == event_type
    end
    
    context "given event does not have a type" do
      let(:event) { Hash[:type => nil] }
      
      it "fails with an error if no type is available" do
        expect { publisher.type }.to raise_error(StripeEvent::InvalidEventTypeError)
      end
    end
  end
end
