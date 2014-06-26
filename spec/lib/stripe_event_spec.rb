require 'spec_helper'

describe StripeEvent do
  let(:events) { [] }
  let(:subscriber) { ->(evt){ events << evt } }
  let(:charge_succeeded) { double('charge succeeded') }
  let(:charge_failed) { double('charge failed') }

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

  describe "subscribing to all or only live events" do
    context "when we want to subscribe to only live events" do
      before do
        StripeEvent.ignore_test_webhooks = true
      end

      after do
        StripeEvent.ignore_test_webhooks = false
      end

      def run_webhook
        StripeEvent.subscribe('charge.succeeded', &subscriber)
        StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded', livemode: livemode)
      end

      context "when we have a test event" do
        let(:livemode) { false }

        before do
          run_webhook
        end

        it "does not call the subscriber when we have a test event" do
          expect(events).to be_empty
        end
      end

      context "when we have a live event" do
        let(:livemode) { true }

        before do
          expect(charge_succeeded).to receive(:[]).with(:type).and_return('charge.succeeded')
          expect(Stripe::Event).to receive(:retrieve).with('evt_charge_succeeded').and_return(charge_succeeded)
          run_webhook
        end

        it "calls the subscriber when we have a live event" do
          expect(events).to eq [charge_succeeded]
        end
      end
    end
  end

  describe "subscribing to the 'account.application.deauthorized' event type" do
    before do
      expect(Stripe::Event).to receive(:retrieve).with('evt_account_application_deauthorized').and_raise(Stripe::AuthenticationError)
    end

    context "with a subscriber params with symbolized keys" do
      it "calls the subscriber with the retrieved event" do
        StripeEvent.subscribe('account.application.deauthorized', subscriber)

        StripeEvent.instrument(id: 'evt_account_application_deauthorized', type: 'account.application.deauthorized')

        expect(events.first.type).to    eq 'account.application.deauthorized'
        expect(events.first[:type]).to  eq 'account.application.deauthorized'
      end
    end

    # The Stripe api expects params to be passed into their StripeObject's
    # with symbolized keys, but the params that we pass through from a
    # accont.application.deauthorized webhook are a HashWithIndifferentAccess
    # (keys stored as strings always.
    context "with a subscriber params with indifferent access (stringified keys)" do
      it "calls the subscriber with the retrieved event" do
        StripeEvent.subscribe('account.application.deauthorized', subscriber)

        StripeEvent.instrument({ id: 'evt_account_application_deauthorized', type: 'account.application.deauthorized' }.with_indifferent_access)

        expect(events.first.type).to    eq 'account.application.deauthorized'
        expect(events.first[:type]).to  eq 'account.application.deauthorized'
      end
    end
  end

  describe "subscribing to a namespace of event types" do
    let(:card_created) { double('card created') }
    let(:card_updated) { double('card updated') }

    before do
      expect(card_created).to receive(:[]).with(:type).and_return('customer.card.created')
      expect(Stripe::Event).to receive(:retrieve).with('evt_card_created').and_return(card_created)

      expect(card_updated).to receive(:[]).with(:type).and_return('customer.card.updated')
      expect(Stripe::Event).to receive(:retrieve).with('evt_card_updated').and_return(card_updated)
    end

    context "with a block subscriber" do
      it "calls the subscriber with any events in the namespace" do
        StripeEvent.subscribe('customer.card', &subscriber)

        StripeEvent.instrument(id: 'evt_card_created', type: 'customer.card.created')
        StripeEvent.instrument(id: 'evt_card_updated', type: 'customer.card.updated')

        expect(events).to eq [card_created, card_updated]
      end
    end

    context "with a subscriber that responds to #call" do
      it "calls the subscriber with any events in the namespace" do
        StripeEvent.subscribe('customer.card.', subscriber)

        StripeEvent.instrument(id: 'evt_card_updated', type: 'customer.card.updated')
        StripeEvent.instrument(id: 'evt_card_created', type: 'customer.card.created')

        expect(events).to eq [card_updated, card_created]
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

    context "with a subscriber that responds to #call" do
      it "calls the subscriber with all retrieved events" do
        StripeEvent.all(subscriber)

        StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')
        StripeEvent.instrument(id: 'evt_charge_failed', type: 'charge.failed')

        expect(events).to eq [charge_succeeded, charge_failed]
      end
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
