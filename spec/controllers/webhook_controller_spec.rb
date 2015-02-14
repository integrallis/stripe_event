require 'rails_helper'
require 'spec_helper'

describe StripeEvent::WebhookController do
  def stub_event(identifier, status = 200)
    stub_request(:get, "https://api.stripe.com/v1/events/#{identifier}").
      to_return(status: status, body: File.read("spec/support/fixtures/#{identifier}.json"))
  end

  def webhook(params)
    post :event, params.merge(use_route: :stripe_event)
  end

  it "succeeds with valid event data" do
    count = 0
    StripeEvent.subscribe('charge.succeeded') { |evt| count += 1 }
    stub_event('evt_charge_succeeded')

    webhook id: 'evt_charge_succeeded'

    expect(response.code).to eq '200'
    expect(count).to eq 1
  end

  it "succeeds when the event_retriever returns nil (simulating an ignored webhook event)" do
    count = 0
    StripeEvent.event_retriever = lambda { |params| return nil }
    StripeEvent.subscribe('charge.succeeded') { |evt| count += 1 }
    stub_event('evt_charge_succeeded')

    webhook id: 'evt_charge_succeeded'

    expect(response.code).to eq '200'
    expect(count).to eq 0
  end

  it "calls the event finalizer if there is one" do
    count = 0
    StripeEvent.event_finalizer = lambda { |event| count += 1 }
    stub_event('evt_charge_succeeded')

    webhook id: 'evt_charge_succeeded'

    expect(response.code).to eq '200'
    expect(count).to eq 1
  end

  it "denies access with invalid event data" do
    count = 0
    StripeEvent.subscribe('charge.succeeded') { |evt| count += 1 }
    stub_event('evt_invalid_id', 404)

    webhook id: 'evt_invalid_id'

    expect(response.code).to eq '401'
    expect(count).to eq 0
  end

  it "ensures user-generated Stripe exceptions pass through" do
    StripeEvent.subscribe('charge.succeeded') { |evt| raise Stripe::StripeError, "testing" }
    stub_event('evt_charge_succeeded')

    expect { webhook id: 'evt_charge_succeeded' }.to raise_error(Stripe::StripeError, /testing/)
  end
end
