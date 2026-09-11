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
    timestamp = Time.now

    # compute_signature was private until version 5.19.0 when it was made
    # public and had it's API changed to split timestamp to a separate field.
    signer = Stripe::Webhook::Signature.method(:compute_signature)
    signature =
      if signer.arity == 3
        signer.call(timestamp, payload, secret)
      else
        signer.call("#{timestamp.to_i}.#{payload}", secret)
      end

    "t=#{timestamp.to_i},v1=#{signature}"
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

  context "with multiple signing secrets first of which is nil" do
    before(:each) { StripeEvent.signing_secrets = [nil, secret1, secret2] }

    it "succeeds with valid signature from first secret" do
      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '200'
    end

    it "succeeds with valid signature from second secret" do
      webhook_with_signature charge_succeeded, secret2
      expect(response.code).to eq '200'
    end
  end

  context "raising an error when things go bad and stripe should retry" do
    before(:each) { StripeEvent.signing_secrets = [secret1] }

    it "responds with 4xx" do
      allow(StripeEvent).to receive(:instrument) { raise StripeEvent::ProcessError, "retry please" }
      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '422'
    end
  end

  context "with dynamic signing secrets" do
    it "resolves the provider once per request and observes changes on the next request" do
      provider = double(:provider)
      expect(provider).to receive(:call).once.ordered.and_return([secret1])
      expect(provider).to receive(:call).once.ordered.and_return([secret2])
      StripeEvent.signing_secrets = provider

      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '200'
      webhook_with_signature charge_succeeded, secret2
      expect(response.code).to eq '200'
    end

    [nil, []].each do |empty_secrets|
      it "rejects a provider returning #{empty_secrets.inspect}" do
        StripeEvent.signing_secrets = -> { empty_secrets }
        expect(StripeEvent).not_to receive(:instrument)
        webhook_with_signature charge_succeeded
        expect(response.code).to eq '400'
      end
    end

    it "propagates provider failures without dispatching" do
      StripeEvent.signing_secrets = -> { raise 'Secret store unavailable' }
      expect(StripeEvent).not_to receive(:instrument)
      expect { webhook_with_signature charge_succeeded }.to raise_error('Secret store unavailable')
    end
  end

  context "with named signing sources" do
    let(:platform_events) { [] }
    let(:connect_events) { [] }
    let(:global_events) { [] }

    before do
      StripeEvent.signing_secrets = nil
      StripeEvent.signing_sources = { platform: secret1, connect: secret2 }
      StripeEvent.subscribe('charge.succeeded', source: :platform) { |event| platform_events << event }
      StripeEvent.subscribe('charge.succeeded', source: :connect) { |event| connect_events << event }
      StripeEvent.all { |event| global_events << event }
    end

    it "routes the same payload according to the verified signing secret" do
      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '200'
      expect(platform_events.length).to eq 1
      expect(connect_events).to be_empty

      webhook_with_signature charge_succeeded, secret2
      expect(response.code).to eq '200'
      expect(platform_events.length).to eq 1
      expect(connect_events.length).to eq 1
      expect(global_events.length).to eq 2
      expect(platform_events.first).to be_a(Stripe::Event)
      expect(platform_events.first).to equal(global_events.first)
      expect(platform_events.first.id).to eq connect_events.first.id
    end

    it "does not let the event account override the verified source" do
      payload = charge_succeeded.merge('account' => 'acct_connected')
      webhook_with_signature payload, secret1
      expect(platform_events.length).to eq 1
      expect(connect_events).to be_empty
    end

    it "routes old and new rotation secrets to the same source" do
      StripeEvent.signing_sources = { platform: [secret1, 'rotated-secret'], connect: secret2 }
      [secret1, 'rotated-secret'].each do |secret|
        webhook_with_signature charge_succeeded, secret
        expect(response.code).to eq '200'
      end
      expect(platform_events.length).to eq 2
      expect(connect_events).to be_empty
      expect(global_events.length).to eq 2
    end

    it "delivers only once when multiple rotation signatures match" do
      StripeEvent.signing_sources = { platform: [secret1, 'rotated-secret'] }
      timestamp = Time.now.to_i
      payload = charge_succeeded.to_json
      signatures = [secret1, 'rotated-secret'].map do |secret|
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, "#{timestamp}.#{payload}")
      end
      webhook "t=#{timestamp},v1=#{signatures.join(',v1=')}", charge_succeeded
      expect(response.code).to eq '200'
      expect(platform_events.length).to eq 1
      expect(global_events.length).to eq 1
    end

    it "evaluates every source provider once per request and refreshes on the next request" do
      platform = double(:platform_provider)
      connect = double(:connect_provider)
      expect(platform).to receive(:call).once.ordered.and_return(secret1)
      expect(platform).to receive(:call).once.ordered.and_return('rotated-secret')
      expect(connect).to receive(:call).twice.and_return(secret2)
      StripeEvent.signing_sources = { platform: platform, connect: connect }
      webhook_with_signature charge_succeeded, secret1
      expect(response.code).to eq '200'
      webhook_with_signature charge_succeeded, 'rotated-secret'
      expect(response.code).to eq '200'
      expect(platform_events.length).to eq 2
    end

    it "supports disabled sources alongside active sources" do
      StripeEvent.signing_sources = { platform: -> { nil }, connect: secret2 }
      webhook_with_signature charge_succeeded, secret2
      expect(response.code).to eq '200'
      expect(connect_events.length).to eq 1
      expect(platform_events).to be_empty
    end

    it "rejects requests when all source providers return no usable secrets" do
      StripeEvent.signing_sources = { platform: -> { [] }, connect: [nil, '', ' '] }
      webhook_with_signature charge_succeeded
      expect(response.code).to eq '400'
      expect(global_events).to be_empty
      expect(platform_events).to be_empty
      expect(connect_events).to be_empty
    end

    [nil, 'invalid signature'].each do |signature|
      it "rejects #{signature.inspect} without delivering to any subscribers" do
        webhook signature, charge_succeeded
        expect(response.code).to eq '400'
        expect(global_events).to be_empty
        expect(platform_events).to be_empty
        expect(connect_events).to be_empty
      end
    end

    it "rejects an unknown signing secret" do
      webhook_with_signature charge_succeeded, 'unknown-secret'
      expect(response.code).to eq '400'
      expect(global_events).to be_empty
      expect(platform_events).to be_empty
      expect(connect_events).to be_empty
    end

    it "rejects a payload modified after signing" do
      signature = generate_signature(charge_succeeded, secret1)
      webhook signature, charge_succeeded.merge('id' => 'evt_tampered')
      expect(response.code).to eq '400'
      expect(global_events).to be_empty
    end

    it "rejects an expired signature even when its source secret matches" do
      timestamp = Time.now.to_i - 3600
      payload = charge_succeeded.to_json
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret1, "#{timestamp}.#{payload}")
      webhook "t=#{timestamp},v1=#{signature}", charge_succeeded
      expect(response.code).to eq '400'
      expect(global_events).to be_empty
    end

    it "fails ambiguous configuration before attempting signature verification" do
      StripeEvent.signing_sources = { platform: secret1, connect: -> { secret1 } }
      expect(Stripe::Webhook).not_to receive(:construct_event)
      expect { webhook_with_signature charge_succeeded }.to raise_error(ArgumentError, /multiple sources/)
      expect(global_events).to be_empty
    end

    it "propagates source provider errors without delivering events" do
      StripeEvent.signing_sources = { platform: secret1, connect: -> { raise 'Secret store unavailable' } }
      expect { webhook_with_signature charge_succeeded }.to raise_error('Secret store unavailable')
      expect(global_events).to be_empty
    end

    it "routes a legacy secret only to global subscribers" do
      StripeEvent.signing_secret = 'legacy-secret'
      webhook_with_signature charge_succeeded, 'legacy-secret'
      expect(response.code).to eq '200'
      expect(global_events.length).to eq 1
      expect(platform_events).to be_empty
      expect(connect_events).to be_empty
    end

    it "suppresses global and scoped subscribers when filtered out" do
      StripeEvent.event_filter = ->(_) { nil }
      webhook_with_signature charge_succeeded
      expect(response.code).to eq '200'
      expect(global_events).to be_empty
      expect(platform_events).to be_empty
      expect(connect_events).to be_empty
    end

    it "returns the existing retry response for scoped processing failures" do
      StripeEvent.all(source: :platform) { |_| raise StripeEvent::ProcessError }
      webhook_with_signature charge_succeeded
      expect(response.code).to eq '422'
    end

    it "propagates unexpected scoped handler errors" do
      StripeEvent.all(source: :platform) { |_| raise 'Handler failed' }
      expect { webhook_with_signature charge_succeeded }.to raise_error('Handler failed')
    end
  end
end
