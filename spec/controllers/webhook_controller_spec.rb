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

  before do
    @called = false
    StripeEvent.subscribe('charge.succeeded') { |evt| @called = true }
  end

  it "succeeds with valid event data" do
    stub_event('evt_charge_succeeded')

    webhook id: 'evt_charge_succeeded'

    expect(response.code).to eq '200'
    expect(@called).to be_true
  end

  it "denies access with invalid event data" do
    stub_event('evt_invalid_id', 404)

    webhook id: 'evt_invalid_id'

    expect(response.code).to eq '401'
    expect(@called).to be_false
  end

  it "ensures user-generated Stripe exceptions pass through" do
    StripeEvent.subscribe('charge.succeeded') { |evt| raise Stripe::StripeError }
    stub_event('evt_charge_succeeded')

    expect { webhook id: 'evt_charge_succeeded' }.to raise_error(Stripe::StripeError)
  end
end
