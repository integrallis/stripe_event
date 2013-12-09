require 'spec_helper'

describe StripeEvent do
  let(:events) { [] }
  let(:subscriber) { ->(evt){ events << evt } }
  let(:charge_succeeded) { double('charge succeeded') }
  let(:charge_failed) { double('charge failed') }

  it "calls the subscriber with the retrieved event" do
    StripeEvent.subscribe('charge.succeeded', &subscriber)

    expect(charge_succeeded).to receive(:[]).with(:type).and_return('charge.succeeded')
    expect(Stripe::Event).to receive(:retrieve).with('evt_charge_succeeded').and_return(charge_succeeded)

    StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')

    expect(events).to eq [charge_succeeded]
  end

  it "calls the subscriber with any retrieved events" do
    StripeEvent.all(&subscriber)

    expect(charge_succeeded).to receive(:[]).with(:type).and_return('charge.succeeded')
    expect(Stripe::Event).to receive(:retrieve).with('evt_charge_succeeded').and_return(charge_succeeded)

    StripeEvent.instrument(id: 'evt_charge_succeeded', type: 'charge.succeeded')

    expect(charge_failed).to receive(:[]).with(:type).and_return('charge.failed')
    expect(Stripe::Event).to receive(:retrieve).with('evt_charge_failed').and_return(charge_failed)

    StripeEvent.instrument(id: 'evt_charge_failed', type: 'charge.failed')

    expect(events).to eq [charge_succeeded, charge_failed]
  end

  describe StripeEvent::NotificationAdapter do
    it "calls the subscriber with the last argument" do
      expect(subscriber).to receive(:call).with(:last)

      adapter = StripeEvent::NotificationAdapter.new(subscriber)
      adapter.call(:first, :last)
    end
  end
end
