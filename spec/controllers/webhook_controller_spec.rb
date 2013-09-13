require 'spec_helper'

describe StripeEvent::WebhookController do
  def event_post(params)
    post :event, params.merge(:use_route => :stripe_event)
  end

  it "succeeds with valid event data" do
    stub_event('evt_charge_succeeded')

    event_post :id => 'evt_charge_succeeded'
    expect(response).to be_success
  end

  it "denies access with invalid event data" do
    stub_event('evt_invalid_id', 404)

    event_post :id => 'evt_invalid_id'
    expect(response.code).to eq '401'
  end

  it "ensures user-generated Stripe exceptions pass through" do
    StripeEvent.setup do
      subscribe('charge.succeeded') { |e| raise Stripe::StripeError }
    end
    stub_event('evt_charge_succeeded')

    expect {event_post :id => 'evt_charge_succeeded'}.to raise_error(Stripe::StripeError)
  end

  it "succeeds with a custom event retriever" do
    StripeEvent.event_retriever = Proc.new { |params| params }

    event_post :id => '1'
    expect(response).to be_success
  end
end
