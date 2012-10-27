require 'spec_helper'

describe StripeEvent::Subscriber do
  it "requires valid event types" do
    expect {
      StripeEvent::Subscriber.new('fake.event_type')
    }.to raise_error(StripeEvent::InvalidEventTypeError)
  end

  describe "#register" do
    let(:event_type) { StripeEvent::TYPE_LIST.sample }

    it "is successful" do
      subscriber = StripeEvent::Subscriber.new(event_type).register { |e| }
      subscribers_for_type(event_type).should include(subscriber)
    end
  end

  describe "#pattern" do

    context "single type" do
      let(:event_type) { StripeEvent::TYPE_LIST.sample }

      it "matches the given type" do
        subscriber = StripeEvent::Subscriber.new(event_type)
        subscriber.pattern.should === event_type
      end

      it "does not match other types" do
        subscriber = StripeEvent::Subscriber.new(event_type)
        other_types = StripeEvent::TYPE_LIST - [event_type]
        other_types.each do |type|
          subscriber.pattern.should_not === type
        end
      end
    end

    context "many types" do
      let(:event_types) { StripeEvent::TYPE_LIST.sample(5) }

      it "matches the given types" do
        subscriber = StripeEvent::Subscriber.new(*event_types)
        event_types.each do |type|
          subscriber.pattern.should === type
        end
      end

      it "does not match other types" do
        subscriber = StripeEvent::Subscriber.new(*event_types)
        other_types = StripeEvent::TYPE_LIST - event_types
        other_types.each do |type|
          subscriber.pattern.should_not === type
        end
      end
    end

    context "all types" do
      it "matches all types" do
        subscriber = StripeEvent::Subscriber.new
        StripeEvent::TYPE_LIST.each do |type|
          subscriber.pattern.should === type
        end
      end
    end
  end
end
