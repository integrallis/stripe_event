require 'spec_helper'

describe StripeEvent do
  let(:events) { [] }
  let(:subscriber) { ->(evt){ events << evt } }
  let(:charge_succeeded) { double('charge succeeded') }
  let(:charge_failed) { double('charge failed') }

  describe "subscribing to a specific event type" do
    before do
      expect(charge_succeeded).to receive(:[]).with(:type).and_return('charge.succeeded')
      expect(Stripe::Event).to receive(:retrieve).with('evt_charge_succeeded').and_return(charge_succeeded)
    end

    context "with a block subscriber" do
      it "calls the subscriber with the retrieved event" do
        StripeEvent.subscribe('charge.succeeded', &subscriber)
        StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')

        expect(events).to eq [charge_succeeded]
      end
    end

    context "with a subscriber that responds to #call" do
      it "calls the subscriber with the retrieved event" do
        StripeEvent.subscribe('charge.succeeded', subscriber)
        StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')

        expect(events).to eq [charge_succeeded]
      end
    end
  end

  describe "subscribing to all event types" do
    before do
      expect(charge_succeeded).to receive(:[]).with(:type).and_return('charge.succeeded')
      expect(Stripe::Event).to receive(:retrieve).with('evt_charge_succeeded').and_return(charge_succeeded)

      expect(charge_failed).to receive(:[]).with(:type).and_return('charge.failed')
      expect(Stripe::Event).to receive(:retrieve).with('evt_charge_failed').and_return(charge_failed)
    end

    context "with a block subscriber" do
      it "calls the subscriber with all retrieved events" do
        StripeEvent.all(&subscriber)

        StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')
        StripeEvent.instrument(id: 'evt_charge_failed', type: 'charge.failed')

        expect(events).to eq [charge_succeeded, charge_failed]
      end
    end

    context "with a subscriber the responds to #call" do
      it "calls the subscriber with all retrieved events" do
        StripeEvent.all(subscriber)

        StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')
        StripeEvent.instrument(id: 'evt_charge_failed', type: 'charge.failed')

        expect(events).to eq [charge_succeeded, charge_failed]
      end
    end
  end

  describe StripeEvent::NotificationAdapter do
    it "calls the subscriber with the last argument" do
      expect(subscriber).to receive(:call).with(:last)

      adapter = StripeEvent::NotificationAdapter.new(subscriber)
      adapter.call(:first, :last)
    end
  end

  describe StripeEvent::Namespace do
    let(:namespace) { StripeEvent.namespace }

    describe "#call" do
      it "prepends the namespace to a given string" do
        expect(namespace.call('foo.bar')).to eq '__stripe_event__.foo.bar'
      end

      it "returns the namespace given no arguments" do
        expect(namespace.call).to eq namespace.value
      end
    end

    describe "#to_regexp" do
      it "matches namespaced strings" do
        expect(namespace.to_regexp('foo.bar')).to match namespace.call('foo.bar')
      end

      it "matches all namespaced strings given no arguments" do
        expect(namespace.to_regexp).to match namespace.call('foo.bar')
      end
    end
  end
end
