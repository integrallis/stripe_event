require 'spec_helper'

describe StripeEvent do
  let(:events) { [] }
  let(:subscriber) { ->(evt){ events << evt } }
  let(:charge_succeeded) { Stripe::Event.construct_from(id: 'evt_charge_succeeded', type: 'charge.succeeded') }
  let(:charge_failed) { Stripe::Event.construct_from(id: 'evt_charge_failed', type: 'charge.failed') }
  let(:card_created) { Stripe::Event.construct_from(id: 'event_card_created', type: 'customer.card.created') }
  let(:card_updated) { Stripe::Event.construct_from(id: 'event_card_updated', type: 'customer.card.updated') }

  describe ".configure" do
    it "yields itself to the block" do
      yielded = nil
      StripeEvent.configure { |events| yielded = events }
      expect(yielded).to eq StripeEvent
    end

    it "requires a block argument" do
      expect { StripeEvent.configure }.to raise_error ArgumentError
    end

    describe ".setup - deprecated" do
      it "evaluates the block in its own context" do
        ctx = nil
        StripeEvent.setup { ctx = self }
        expect(ctx).to eq StripeEvent
      end
    end
  end

  describe "subscribing to a specific event type" do
    context "with a block subscriber" do
      it "calls the subscriber with the retrieved event" do
        StripeEvent.subscribe('charge.succeeded', &subscriber)

        StripeEvent.instrument(charge_succeeded)

        expect(events).to eq [charge_succeeded]
      end
    end

    context "with a subscriber that responds to #call" do
      it "calls the subscriber with the retrieved event" do
        StripeEvent.subscribe('charge.succeeded', subscriber)

        StripeEvent.instrument(charge_succeeded)

        expect(events).to eq [charge_succeeded]
      end
    end
  end

  describe "subscribing to a namespace of event types" do
    context "with a block subscriber" do
      it "calls the subscriber with any events in the namespace" do
        StripeEvent.subscribe('customer.card', &subscriber)

        StripeEvent.instrument(card_created)
        StripeEvent.instrument(card_updated)

        expect(events).to eq [card_created, card_updated]
      end
    end

    context "with a subscriber that responds to #call" do
      it "calls the subscriber with any events in the namespace" do
        StripeEvent.subscribe('customer.card.', subscriber)

        StripeEvent.instrument(card_updated)
        StripeEvent.instrument(card_created)

        expect(events).to eq [card_updated, card_created]
      end
    end
  end

  describe "subscribing to all event types" do
    context "with a block subscriber" do
      it "calls the subscriber with all retrieved events" do
        StripeEvent.all(&subscriber)

        StripeEvent.instrument(charge_succeeded)
        StripeEvent.instrument(charge_failed)

        expect(events).to eq [charge_succeeded, charge_failed]
      end
    end

    context "with a subscriber that responds to #call" do
      it "calls the subscriber with all retrieved events" do
        StripeEvent.all(subscriber)

        StripeEvent.instrument(charge_succeeded)
        StripeEvent.instrument(charge_failed)

        expect(events).to eq [charge_succeeded, charge_failed]
      end
    end
  end

  describe ".listening?" do
    it "returns true when there is a subscriber for a matching event type" do
      StripeEvent.subscribe('customer.', &subscriber)

      expect(StripeEvent.listening?('customer.card')).to be true
      expect(StripeEvent.listening?('customer.')).to be true
    end

    it "returns false when there is not a subscriber for a matching event type" do
      StripeEvent.subscribe('customer.', &subscriber)

      expect(StripeEvent.listening?('account')).to be false
    end

    it "returns true when a subscriber is subscribed to all events" do
      StripeEvent.all(&subscriber)

      expect(StripeEvent.listening?('customer.')).to be true
      expect(StripeEvent.listening?('account')).to be true
    end
  end

  describe StripeEvent::NotificationAdapter do
    let(:adapter) { StripeEvent.adapter }

    it "calls the subscriber with the last argument" do
      expect(subscriber).to receive(:call).with(:last)

      adapter.call(subscriber).call(:first, :last)
    end
  end

  describe StripeEvent::Namespace do
    let(:namespace) { StripeEvent.namespace }

    describe "#call" do
      it "prepends the namespace to a given string" do
        expect(namespace.call('foo.bar')).to eq 'stripe_event.foo.bar'
      end

      it "returns the namespace given no arguments" do
        expect(namespace.call).to eq 'stripe_event.'
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
