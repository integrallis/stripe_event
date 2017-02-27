require 'rails_helper'
require 'spec_helper'

describe StripeEvent::WebhookController do
  include_context 'restore_state'

  routes { StripeEvent::Engine.routes }

  def payload(identifier)
    File.read("spec/support/fixtures/#{identifier}.json")
  end

  def stub_event(identifier, status = 200)
    stub_request(:get, "https://api.stripe.com/v1/events/#{identifier}").
      to_return(status: status, body: payload(identifier))
  end

  def webhook(params)
    post :event, params
  end

  routes { StripeEvent::Engine.routes }

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

  context "with an authentication secret" do
    def webhook_with_secret(secret, params)
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('user', secret)
      webhook params
    end

    before(:each) { StripeEvent.authentication_secret = "secret" }
    after(:each) { StripeEvent.authentication_secret = nil }

    it "rejects requests with no secret" do
      stub_event('evt_charge_succeeded')

      webhook id: 'evt_charge_succeeded'
      expect(response.code).to eq '401'
    end

    it "rejects requests with incorrect secret" do
      stub_event('evt_charge_succeeded')

      webhook_with_secret 'incorrect', id: 'evt_charge_succeeded'
      expect(response.code).to eq '401'
    end

    it "accepts requests with correct secret" do
      stub_event('evt_charge_succeeded')

      webhook_with_secret 'secret', id: 'evt_charge_succeeded'
      expect(response.code).to eq '200'
    end
  end

  context 'with trust incoming event true' do
    let(:trust_event) { true }

    it 'succeeds with valid event data' do
      count = 0
      StripeEvent.event_retriever = nil
      StripeEvent.subscribe('charge.succeeded') { |evt| count += 1 }
      post :event, JSON.parse(payload('evt_charge_succeeded'))

      expect(response.code).to eq '200'
      expect(count).to eq 1
    end

    it 'define custom event_retriever' do
      custom_event_retriever = lambda { |evt| nil }
      StripeEvent.event_retriever = custom_event_retriever
      post :event, JSON.parse(payload('evt_charge_succeeded'))

      expect(response.code).to eq '200'
      expect(StripeEvent.event_retriever).to eq custom_event_retriever
    end
  end
end
