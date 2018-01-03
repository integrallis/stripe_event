require 'spec_helper'

RSpec.describe StripeEvent do
  let(:events) { [] }
  let(:subscriber) { ->(event) { events << event } }
  let(:charge_succeeded) { Stripe::Event.construct_from(id: 'evt_charge_succeeded', type: 'charge.succeeded') }
  let(:charge_failed) { Stripe::Event.construct_from(id: 'evt_charge_failed', type: 'charge.failed') }
  let(:card_created) { Stripe::Event.construct_from(id: 'event_card_created', type: 'customer.card.created') }
  let(:card_updated) { Stripe::Event.construct_from(id: 'event_card_updated', type: 'customer.card.updated') }

  describe '.configure' do
    let(:configurer) { proc {} }
    let(:configuration) { instance_double(StripeEvent::Configuration) }

    before do
      allow(configuration).to receive(:configure)
      allow(StripeEvent::Configuration).to receive(:instance) { configuration }
      described_class.configure(&configurer)
    end

    it do
      expect(configuration).to have_received(:configure) do |&block|
        expect(block).to eq(configurer.to_proc)
      end
    end
  end

  describe '.subscribe' do
    context 'subscribing to a specific event type' do
      context 'with a block subscriber' do
        before do
          described_class.subscribe('charge.succeeded', &subscriber)
          described_class.instrument(charge_succeeded)
        end

        it 'calls the subscriber with the retrieved event' do
          expect(events).to match_array([charge_succeeded])
        end
      end

      context 'with a subscriber that responds to #call' do
        before do
          described_class.subscribe('charge.succeeded', subscriber)
          described_class.instrument(charge_succeeded)
        end

        it 'calls the subscriber with the retrieved event' do
          expect(events).to match_array([charge_succeeded])
        end
      end
    end

    context 'subscribing to a namespace of event types' do
      context 'with a block subscriber' do
        before do
          described_class.subscribe('customer.card', &subscriber)
          described_class.instrument(card_created)
          described_class.instrument(card_updated)
        end

        it 'calls the subscriber with any events in the namespace' do
          expect(events).to match_array([card_updated, card_created])
        end
      end

      context 'with a subscriber that responds to #call' do
        before do
          described_class.subscribe('customer.card.', subscriber)
          described_class.instrument(card_updated)
          described_class.instrument(card_created)
        end

        it 'calls the subscriber with any events in the namespace' do
          expect(events).to match_array([card_updated, card_created])
        end
      end
    end
  end

  describe '.all' do
    context 'with a block subscriber' do
      before do
        described_class.all(&subscriber)
        described_class.instrument(charge_succeeded)
        described_class.instrument(charge_failed)
      end

      it 'calls the subscriber with all retrieved events' do
        expect(events).to match_array([charge_succeeded, charge_failed])
      end
    end

    context 'with a subscriber that responds to #call' do
      before do
        described_class.all(subscriber)
        described_class.instrument(charge_succeeded)
        described_class.instrument(charge_failed)
      end

      it 'calls the subscriber with all retrieved events' do
        expect(events).to match_array([charge_succeeded, charge_failed])
      end
    end
  end

  describe '.listening?' do
    context 'when there is a subscriber for a matching event type' do
      before { described_class.subscribe('customer.', &subscriber) }

      it { is_expected.to be_listening('customer.card') }
      it { is_expected.to be_listening('customer.') }
    end

    context 'when there is not a subscriber for a matching event type' do
      before { described_class.subscribe('customer.', &subscriber) }

      it { is_expected.not_to be_listening('account') }
    end

    context 'when a subscriber is subscribed to all events' do
      before { described_class.all(&subscriber) }

      it { is_expected.to be_listening('customer.') }
      it { is_expected.to be_listening('account') }
    end
  end
end
