require 'rails_helper'
require 'spec_helper'
require 'rack/mock'
require 'openssl'

describe "Source-restricted engine mounts" do
  let(:platform_secret) { 'platform-secret' }
  let(:connect_secret) { 'connect-secret' }
  let(:deliveries) { [] }
  let(:payload) do
    {
      id: 'evt_checkout', object: 'event', type: 'checkout.session.completed',
      data: { object: { id: 'cs_checkout', object: 'checkout.session' } }
    }
  end

  before do
    StripeEvent.signing_secrets = nil
    StripeEvent.signing_sources = { platform: platform_secret, connect: connect_secret }
    StripeEvent.all { |event| deliveries << [:global, event.id] }
    StripeEvent.all(source: :platform) { |event| deliveries << [:platform, event.id] }
    StripeEvent.all(source: :connect) { |event| deliveries << [:connect, event.id] }
  end

  def webhook(path, secret, data = payload)
    body = JSON.generate(data)
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, "#{timestamp}.#{body}")
    Rack::MockRequest.new(Rails.application).post(path,
      input: body, 'CONTENT_TYPE' => 'application/json',
      'HTTP_STRIPE_SIGNATURE' => "t=#{timestamp},v1=#{signature}")
  end

  it "accepts platform events only at the platform mount and connect events only at the connect mount" do
    expect(webhook('/webhooks/stripe/platform', platform_secret).status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']]
    deliveries.clear

    expect(webhook('/webhooks/stripe/connect', connect_secret).status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:connect, 'evt_checkout']]
  end

  it "rejects a Connect signature at the platform mount" do
    expect(webhook('/webhooks/stripe/platform', connect_secret).status).to eq 400
    expect(deliveries).to be_empty
  end

  it "rejects a platform signature at the Connect mount" do
    expect(webhook('/webhooks/stripe/connect', platform_secret).status).to eq 400
    expect(deliveries).to be_empty
  end

  it "does not attempt verification with secrets from other sources" do
    expect(Stripe::Webhook).to receive(:construct_event).with(anything, anything, platform_secret).and_call_original
    expect(Stripe::Webhook).not_to receive(:construct_event).with(anything, anything, connect_secret)
    expect(webhook('/webhooks/stripe/platform', connect_secret).status).to eq 400
  end

  it "rejects an unknown mount source without falling back to other configured secrets" do
    StripeEvent.signing_sources = { connect: connect_secret }
    expect(Stripe::Webhook).not_to receive(:construct_event)
    expect(webhook('/webhooks/stripe/platform', connect_secret).status).to eq 400
    expect(deliveries).to be_empty
  end

  it "rejects a disabled mount source" do
    StripeEvent.signing_sources = { platform: -> { [nil, ''] }, connect: connect_secret }
    expect(webhook('/webhooks/stripe/platform', connect_secret).status).to eq 400
    expect(deliveries).to be_empty
  end

  it "accepts rotation secrets only at their source's mount" do
    StripeEvent.signing_sources = { platform: [platform_secret, 'rotated-secret'], connect: connect_secret }
    [platform_secret, 'rotated-secret'].each do |secret|
      expect(webhook('/webhooks/stripe/platform', secret).status).to eq 200
      expect(webhook('/webhooks/stripe/connect', secret).status).to eq 400
    end
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']] * 2
  end

  it "ignores query parameters attempting to override the mount source" do
    expect(webhook('/webhooks/stripe/platform?stripe_event_source=connect', connect_secret).status).to eq 400
    expect(deliveries).to be_empty
    expect(webhook('/webhooks/stripe/platform?stripe_event_source=connect', platform_secret).status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']]
  end

  it "ignores body parameters attempting to override the mount source" do
    data = payload.merge(stripe_event_source: 'connect')
    expect(webhook('/webhooks/stripe/platform', connect_secret, data).status).to eq 400
    expect(deliveries).to be_empty
    expect(webhook('/webhooks/stripe/platform', platform_secret, data).status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']]
  end

  it "preserves the shared mount and does not treat query or body fields as routing configuration" do
    expect(webhook('/stripe_event?stripe_event_source=platform', connect_secret,
      payload.merge(stripe_event_source: 'platform')).status).to eq 200
    expect(webhook('/stripe_event', platform_secret).status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:connect, 'evt_checkout'],
      [:global, 'evt_checkout'], [:platform, 'evt_checkout']]
  end

  it "accepts legacy unscoped secrets only at the shared mount" do
    StripeEvent.signing_secret = 'legacy-secret'
    expect(webhook('/webhooks/stripe/platform', 'legacy-secret').status).to eq 400
    expect(webhook('/webhooks/stripe/connect', 'legacy-secret').status).to eq 400
    expect(deliveries).to be_empty
    expect(webhook('/stripe_event', 'legacy-secret').status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout']]
  end

  it "resolves source providers once per request and observes rotation on the next request" do
    platform = double(:platform_provider)
    connect = double(:connect_provider)
    expect(platform).to receive(:call).once.ordered.and_return(platform_secret)
    expect(platform).to receive(:call).once.ordered.and_return('rotated-secret')
    expect(connect).to receive(:call).twice.and_return(connect_secret)
    StripeEvent.signing_sources = { platform: platform, connect: connect }
    expect(webhook('/webhooks/stripe/platform', platform_secret).status).to eq 200
    expect(webhook('/webhooks/stripe/platform', 'rotated-secret').status).to eq 200
    expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']] * 2
  end
  context "when sources share the Stripe CLI secret" do
    before do
      StripeEvent.signing_sources = { platform: 'cli-secret', connect: 'cli-secret' }
    end

    it "dispatches only the fixed mount source and global subscribers once" do
      expect(webhook('/webhooks/stripe/platform', 'cli-secret').status).to eq 200
      expect(webhook('/webhooks/stripe/connect', 'cli-secret').status).to eq 200
      expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout'],
        [:global, 'evt_checkout'], [:connect, 'evt_checkout']]
    end

    it "still requires a valid signature" do
      expect(webhook('/webhooks/stripe/platform', 'wrong-secret').status).to eq 400
      expect(webhook('/webhooks/stripe/connect', 'wrong-secret').status).to eq 400
      expect(deliveries).to be_empty
    end

    it "ignores query and body source overrides on restricted mounts" do
      expect(webhook('/webhooks/stripe/platform?stripe_event_source=connect', 'cli-secret',
        payload.merge(stripe_event_source: 'connect')).status).to eq 200
      expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']]
    end

    it "rejects ambiguous shared mounts even when parameters claim a source" do
      expect(webhook('/stripe_event?stripe_event_source=platform', 'cli-secret',
        payload.merge(stripe_event_source: 'platform')).status).to eq 500
      expect(deliveries).to be_empty
    end

    it "resolves every provider once, including other sources" do
      platform = double(:platform_provider)
      connect = double(:connect_provider)
      expect(platform).to receive(:call).once.and_return(['old-platform', 'cli-secret', 'cli-secret'])
      expect(connect).to receive(:call).once.and_return('cli-secret')
      StripeEvent.signing_sources = { platform: platform, connect: connect }
      expect(webhook('/webhooks/stripe/platform', 'cli-secret').status).to eq 200
      expect(deliveries).to eq [[:global, 'evt_checkout'], [:platform, 'evt_checkout']]
    end

    it "propagates another source provider's failure without dispatch" do
      StripeEvent.signing_sources = { platform: 'cli-secret', connect: -> { raise 'provider unavailable' } }
      expect(webhook('/webhooks/stripe/platform', 'cli-secret').status).to eq 500
      expect(deliveries).to be_empty
    end
  end

end
