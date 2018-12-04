require 'rails_helper'
require 'spec_helper'

describe StripeEvent::WebhookController, type: :controller do
  let(:secret1) { 'secret1' }
  let(:secret2) { 'secret2' }
  let(:charge_succeeded) { stub_event('evt_charge_succeeded') }

  def stub_event(identifier)
    JSON.parse(File.read("spec/support/fixtures/#{identifier}.json"))
  end

  def generate_signature(params, secret)
    payload   = params.to_json
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.send(:compute_signature, "#{timestamp}.#{payload}", secret)

    "t=#{timestamp},v1=#{signature}"
  end

  def webhook(signature, params)
    request.env['HTTP_STRIPE_SIGNATURE'] = signature
    request.env['RAW_POST_DATA'] = params.to_json # works with Rails 3, 4, or 5
    post :event, body: params.to_json
  end

  def webhook_with_signature(params, secret = secret1)
    webhook generate_signature(params, secret), params
  end

  routes { StripeEvent::Engine.routes }

  context "without a signing secret" do
    before(:each) { StripeEvent.signing_secret = nil }

    it "denies invalid signature" do
      webhook "invalid signature", charge_succeeded
      expect(response.code).to eq '400'
    end

    it "denies valid signature" do
      webhook_with_signature charge_succeeded
      expect(response.code).to eq '400'
    end
  end

  context "with a signing secret" do
    before(:each) { StripeEvent.signing_secret = secret1 }

    it "denies missing signature" do
      webhook nil, charge_succeeded
      expect(response.code).to eq '400'
    end

    it "denies invalid signature" do
      webhook "invalid signature", charge_succeeded
      expect(response.code).to eq '400'
    end

    it "denies signature from wrong secret" do
      webhook_with_signature charge_succeeded, 'bogus'
      expect(response.code).to eq '400'
    end

    it "succeeds with valid signature from correct secret" do
      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '200'
    end

    it "succeeds with valid event data" do
      count = 0
      StripeEvent.subscribe('charge.succeeded') { |evt| count += 1 }

      webhook_with_signature charge_succeeded

      expect(response.code).to eq '200'
      expect(count).to eq 1
    end

    it "succeeds when the event_filter returns nil (simulating an ignored webhook event)" do
      count = 0
      StripeEvent.event_filter = lambda { |event| return nil }
      StripeEvent.subscribe('charge.succeeded') { |evt| count += 1 }

      webhook_with_signature charge_succeeded

      expect(response.code).to eq '200'
      expect(count).to eq 0
    end

    it "ensures user-generated Stripe exceptions pass through" do
      StripeEvent.subscribe('charge.succeeded') { |evt| raise Stripe::StripeError, "testing" }

      expect { webhook_with_signature(charge_succeeded) }.to raise_error(Stripe::StripeError, /testing/)
    end
  end

  context "with multiple signing secrets" do
    before(:each) { StripeEvent.signing_secrets = [secret1, secret2] }

    it "denies missing signature" do
      webhook nil, charge_succeeded
      expect(response.code).to eq '400'
    end

    it "denies invalid signature" do
      webhook "invalid signature", charge_succeeded
      expect(response.code).to eq '400'
    end

    it "denies signature from wrong secret" do
      webhook_with_signature charge_succeeded, 'bogus'
      expect(response.code).to eq '400'
    end

    it "succeeds with valid signature from first secret" do
      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '200'
    end

    it "succeeds with valid signature from second secret" do
      webhook_with_signature charge_succeeded, secret2
      expect(response.code).to eq '200'
    end
  end
end
