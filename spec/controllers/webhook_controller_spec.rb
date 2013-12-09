require 'spec_helper'

describe StripeEvent::WebhookController do
  def webhook(params)
    post :event, params.merge(:use_route => :stripe_event)
  end

  it "succeeds with valid event data" do
    stub_event('evt_charge_succeeded')

    webhook :id => 'evt_charge_succeeded'
    expect(response.code).to eq '200'
  end

  it "denies access with invalid event data" do
    stub_event('evt_invalid_id', 404)

    webhook :id => 'evt_invalid_id'
    expect(response.code).to eq '401'
  end

  it "ensures user-generated Stripe exceptions pass through" do
    StripeEvent.subscribe('charge.succeeded') { |e| raise Stripe::StripeError }
    stub_event('evt_charge_succeeded')

    expect { webhook :id => 'evt_charge_succeeded' }.to raise_error(Stripe::StripeError)
  end
end
