require 'spec_helper'
require 'timeout'

describe "Named signing sources" do
  before do
    StripeEvent.signing_secrets = nil
    StripeEvent.signing_sources = {}
  end

  it "resolves strings, arrays and mixed callable secrets" do
    StripeEvent.signing_sources = {
      platform: 'platform-secret',
      connect: ['old-secret', -> { ['new-secret', nil] }]
    }
    expect(StripeEvent.signing_candidates).to eq [
      ['platform', 'platform-secret'], ['connect', 'old-secret'], ['connect', 'new-secret']
    ]
  end

  it "resolves each provider once and refreshes it on the next lookup" do
    provider = double(:provider)
    expect(provider).to receive(:call).once.ordered.and_return('old-secret')
    expect(provider).to receive(:call).once.ordered.and_return(['new-secret'])
    StripeEvent.signing_sources = { platform: provider }
    expect(StripeEvent.signing_candidates).to eq [['platform', 'old-secret']]
    expect(StripeEvent.signing_candidates).to eq [['platform', 'new-secret']]
  end

  it "combines legacy secrets with named sources" do
    StripeEvent.signing_secrets = ['legacy-secret']
    StripeEvent.signing_sources = { platform: 'platform-secret' }
    expect(StripeEvent.signing_candidates).to eq [[nil, 'legacy-secret'], ['platform', 'platform-secret']]
    expect(StripeEvent.signing_secrets).to eq ['legacy-secret']
  end

  it "ignores nil and blank secrets and deduplicates secrets within a source" do
    StripeEvent.signing_sources = { platform: [nil, '', ' ', 'secret', 'secret', -> { nil }] }
    expect(StripeEvent.signing_candidates).to eq [['platform', 'secret']]
  end

  it "allows a shared secret only when the requested source is explicit" do
    StripeEvent.signing_sources = { platform: 'shared', connect: ['shared', 'connect-only'] }
    expect(StripeEvent.signing_candidates(source: :platform)).to eq [['platform', 'shared']]
    expect(StripeEvent.signing_candidates(source: 'connect')).to eq [['connect', 'shared'], ['connect', 'connect-only']]
    expect(StripeEvent.signing_candidates(source: 'missing')).to eq []
    expect(StripeEvent.signing_candidates(source: '')).to eq []
    expect { StripeEvent.signing_candidates }.to raise_error(ArgumentError, /multiple sources/)
  end

  it "rejects secrets shared by named sources without disclosing them" do
    StripeEvent.signing_sources = { platform: 'private-secret', connect: -> { 'private-secret' } }
    expect { StripeEvent.signing_candidates }.to raise_error(ArgumentError) { |error|
      expect(error.message).not_to include('private-secret')
    }
  end

  it "rejects secrets shared by named and unscoped configuration" do
    StripeEvent.signing_secret = 'shared-secret'
    StripeEvent.signing_sources = { platform: 'shared-secret' }
    expect { StripeEvent.signing_candidates }.to raise_error(ArgumentError, /multiple sources/)
  end

  it "rejects duplicate names after normalizing strings and symbols" do
    expect {
      StripeEvent.signing_sources = { :platform => 'one', 'platform' => 'two' }
    }.to raise_error(ArgumentError, /Duplicate signing source/)
  end

  it "requires a hash with nonempty string or symbol names" do
    expect { StripeEvent.signing_sources = [] }.to raise_error(ArgumentError)
    expect { StripeEvent.signing_sources = false }.to raise_error(ArgumentError)
    [nil, false, 1, '', "platform\nstripe_event."].each do |source|
      expect { StripeEvent.signing_sources = { source => 'secret' } }.to raise_error(ArgumentError)
    end
  end

  it "clears named sources without changing legacy secrets" do
    StripeEvent.signing_secret = 'legacy'
    StripeEvent.signing_sources = { platform: 'secret' }
    StripeEvent.signing_sources = nil
    expect(StripeEvent.signing_candidates).to eq [[nil, 'legacy']]
  end
end

describe "Source-scoped subscriptions" do
  let(:event) { Stripe::Event.construct_from(id: 'evt_checkout', type: 'checkout.session.completed') }
  let(:received) { [] }
  let(:subscriber) { ->(value) { received << value } }

  it "delivers the original event only to the matching source and each global subscriber once" do
    platform = double(:platform)
    connect = double(:connect)
    expect(platform).to receive(:call).once.with(event)
    expect(connect).not_to receive(:call)
    StripeEvent.subscribe('checkout.session.completed', platform, source: :platform)
    StripeEvent.subscribe('checkout.session.completed', connect, source: :connect)
    StripeEvent.subscribe('checkout.session.completed', subscriber)
    StripeEvent.all(subscriber)

    StripeEvent.instrument(event, source: 'platform')
    expect(received).to eq [event, event]
    expect(received.first).to equal(event)
  end

  it "supports prefix subscriptions and blocks within a source" do
    StripeEvent.subscribe('checkout.', source: :platform, &subscriber)
    StripeEvent.instrument(event, source: :connect)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to eq [event]
  end

  it "supports source-scoped all with callable objects and blocks" do
    StripeEvent.all(subscriber, source: :platform)
    StripeEvent.all(source: :platform, &subscriber)
    StripeEvent.instrument(event, source: :connect)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to eq [event, event]
  end

  it "does not deliver a different event type to a scoped subscriber" do
    StripeEvent.subscribe('invoice.', source: :platform, &subscriber)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to be_empty
  end

  it "delivers direct instrumentation without a source only to global subscribers" do
    StripeEvent.all(source: :platform, &subscriber)
    StripeEvent.all(&subscriber)
    StripeEvent.instrument(event)
    expect(received).to eq [event]
  end

  it "does not infer the source from the event account" do
    event[:account] = 'acct_connected'
    StripeEvent.all(source: :platform, &subscriber)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to eq [event]
  end

  it "applies the event filter once and delivers its replacement to both streams" do
    replacement = Stripe::Event.construct_from(id: 'evt_filtered', type: 'invoice.paid')
    filter = double(:filter)
    expect(filter).to receive(:call).once.with(event).and_return(replacement)
    StripeEvent.event_filter = filter
    StripeEvent.subscribe('invoice.paid', subscriber)
    StripeEvent.subscribe('invoice.paid', subscriber, source: :platform)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to eq [replacement, replacement]
  end

  it "suppresses both streams when the filter returns nil" do
    StripeEvent.event_filter = ->(_) { nil }
    StripeEvent.all(&subscriber)
    StripeEvent.all(source: :platform, &subscriber)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to be_empty
  end

  it "selects both streams before subscribers can change the event type" do
    StripeEvent.all { |value| value[:type] = 'invoice.paid' }
    StripeEvent.subscribe('checkout.session.completed', source: :platform, &subscriber)
    StripeEvent.instrument(event, source: :platform)
    expect(received).to eq [event]
  end

  it "propagates scoped subscriber exceptions" do
    StripeEvent.all(source: :platform) { |_| raise StripeEvent::ProcessError, 'retry' }
    expect { StripeEvent.instrument(event, source: :platform) }.to raise_error(StripeEvent::ProcessError)
  end

  it "does not acknowledge a global failure by continuing to scoped subscribers" do
    StripeEvent.all { |_| raise StripeEvent::ProcessError, 'retry' }
    StripeEvent.all(source: :platform, &subscriber)
    expect { StripeEvent.instrument(event, source: :platform) }.to raise_error(StripeEvent::ProcessError)
    expect(received).to be_empty
  end

  it "keeps source names containing delimiters or regex characters separate" do
    StripeEvent.all(source: 'platform.*', &subscriber)
    StripeEvent.instrument(event, source: 'platform.*:other')
    StripeEvent.instrument(event, source: 'platformXYZ')
    StripeEvent.instrument(event, source: 'platform.*')
    expect(received).to eq [event]
  end

  it "uses the configured namespace for both streams" do
    original = StripeEvent.namespace
    begin
      StripeEvent.namespace = StripeEvent::Namespace.new('billing', '/')
      StripeEvent.all(&subscriber)
      StripeEvent.all(source: :platform, &subscriber)
      StripeEvent.instrument(event, source: :platform)
      expect(received).to eq [event, event]
    ensure
      StripeEvent.namespace = original
    end
  end

  it "keeps the existing adapter interface and Stripe event payload" do
    original = StripeEvent.adapter
    begin
      adapter = double(:adapter)
      notification_subscriber = ->(*args) { received << args.last }
      expect(adapter).to receive(:call).with(subscriber).and_return(notification_subscriber)
      StripeEvent.adapter = adapter
      StripeEvent.all(subscriber, source: :platform)
      StripeEvent.instrument(event, source: :platform)
      expect(received).to eq [event]
    ensure
      StripeEvent.adapter = original
    end
  end

  it "does not leak source state across nested deliveries" do
    nested = Stripe::Event.construct_from(id: 'evt_nested', type: event.type)
    StripeEvent.all { |value| StripeEvent.instrument(nested, source: :connect) if value.equal?(event) }
    StripeEvent.all(source: :platform) { |value| received << [:platform, value.id] }
    StripeEvent.all(source: :connect) { |value| received << [:connect, value.id] }
    StripeEvent.instrument(event, source: :platform)
    expect(received).to eq [[:connect, 'evt_nested'], [:platform, 'evt_checkout']]
  end

  it "keeps concurrent deliveries isolated" do
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    StripeEvent.event_filter = ->(value) { ready << true; release.pop; value }
    [:platform, :connect].each do |source|
      StripeEvent.all(source: source) { |value| results << [source, value.id] }
    end
    threads = [:platform, :connect].map do |source|
      Thread.new do
        value = Stripe::Event.construct_from(id: source.to_s, type: 'checkout.session.completed')
        StripeEvent.instrument(value, source: source)
      end
    end
    begin
      Timeout.timeout(5) do
        2.times { ready.pop }
        2.times { release << true }
        threads.each(&:value)
      end
      expect(2.times.map { results.pop(true) }).to match_array([[:platform, 'platform'], [:connect, 'connect']])
      expect(results).to be_empty
    ensure
      threads.each { |thread| thread.kill if thread.alive? }
      threads.each(&:join)
    end
  end

  it "rejects invalid source arguments before any delivery" do
    StripeEvent.all(&subscriber)
    expect { StripeEvent.instrument(event, source: '') }.to raise_error(ArgumentError)
    expect { StripeEvent.all(source: false, &subscriber) }.to raise_error(ArgumentError)
    expect { StripeEvent.listening?(event.type, source: 1) }.to raise_error(ArgumentError)
    expect(received).to be_empty
  end

  it "reports listeners that would receive the specified delivery" do
    StripeEvent.subscribe('checkout.', source: :platform, &subscriber)
    expect(StripeEvent.listening?(event.type, source: 'platform')).to be true
    expect(StripeEvent.listening?(event.type, source: :connect)).to be false
    expect(StripeEvent.listening?(event.type)).to be false
    expect(StripeEvent.listening?('invoice.paid', source: :platform)).to be false
    StripeEvent.all(&subscriber)
    expect(StripeEvent.listening?(event.type, source: :connect)).to be true
  end
end
