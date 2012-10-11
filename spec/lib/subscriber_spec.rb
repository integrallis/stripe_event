require 'spec_helper'

describe StripeEvent::Subscriber do
  let(:subscriber) { StripeEvent::Subscriber.new(*event_types) }

  it "requires valid event types" do
    expect {
      StripeEvent::Subscriber.new('fake.event_type')
    }.to raise_error(StripeEvent::InvalidEventTypeError)
  end

  describe "#register" do
    let(:behavior) { Proc.new{|e|} }
    let(:event_types) { StripeEvent::TYPE_LIST.sample(1) }

    it "is successful" do
      s = subscriber.register(&behavior)
      event_types.each { |type| subscribers_for_type(type).should include(s) }
    end
  end

  describe "#pattern" do
    let(:other_types) { StripeEvent::TYPE_LIST - event_types }

    context "single type" do
      let(:event_types) { StripeEvent::TYPE_LIST.sample(1) }

      it "matches the given type" do
        event_types.each { |type| subscriber.pattern.should === type }
      end

      it "does not match other types" do
        other_types.each { |type| subscriber.pattern.should_not === type }
      end
    end

    context "many types" do
      let(:event_types) { StripeEvent::TYPE_LIST.sample(5) }

      it "matches the given types" do
        event_types.each { |type| subscriber.pattern.should === type }
      end

      it "does not match other types" do
        other_types.each { |type| subscriber.pattern.should_not === type }
      end
    end

    context "all types" do
      let(:event_types) { nil }

      it "matches all types" do
        StripeEvent::TYPE_LIST.each { |type| subscriber.pattern.should === type }
      end
    end
  end
end
