# StripeEvent

[![Build Status](https://github.com/integrallis/stripe_event/workflows/CI/badge.svg)](https://github.com/integrallis/stripe_event/actions?query=workflow%3ACI)
[![Gem Version](https://badge.fury.io/rb/stripe_event.svg)](http://badge.fury.io/rb/stripe_event)
[![Gem Downloads](https://img.shields.io/gem/dt/stripe_event.svg)](https://rubygems.org/gems/stripe_event)

StripeEvent is built on the [ActiveSupport::Notifications API](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html). Incoming webhook requests are [authenticated with the webhook signature](#authenticating-webhooks-with-signatures). Define subscribers to handle specific event types. Subscribers can be a block or an object that responds to `#call`.

## Install

```ruby
# Gemfile
gem 'stripe_event'
```

```ruby
# config/routes.rb
mount StripeEvent::Engine, at: '/my-chosen-path' # provide a custom path
```

## Usage

```ruby
# config/initializers/stripe.rb
Stripe.api_key             = ENV['STRIPE_SECRET_KEY']     # e.g. sk_live_...
StripeEvent.signing_secret = ENV['STRIPE_SIGNING_SECRET'] # e.g. whsec_...

StripeEvent.configure do |events|
  events.subscribe 'charge.failed' do |event|
    # Define subscriber behavior based on the event object
    event.class       #=> Stripe::Event
    event.type        #=> "charge.failed"
    event.data.object #=> #<Stripe::Charge:0x3fcb34c115f8>
  end

  events.all do |event|
    # Handle all event types - logging, etc.
  end
end
```

### Subscriber objects that respond to #call

```ruby
class CustomerCreated
  def call(event)
    # Event handling
  end
end

class BillingEventLogger
  def initialize(logger)
    @logger = logger
  end

  def call(event)
    @logger.info "BILLING:#{event.type}:#{event.id}"
  end
end
```

```ruby
StripeEvent.configure do |events|
  events.all BillingEventLogger.new(Rails.logger)
  events.subscribe 'customer.created', CustomerCreated.new
end
```

### Subscribing to a namespace of event types

```ruby
StripeEvent.subscribe 'customer.card.' do |event|
  # Will be triggered for any customer.card.* events
end
```

## Securing your webhook endpoint

### Authenticating webhooks with signatures

Stripe will cryptographically sign webhook payloads with a signature that is included in a special header sent with the request. Verifying this signature lets your application properly authenticate the request originated from Stripe. **As of [v2.0.0](https://github.com/integrallis/stripe_event/releases/tag/v2.0.0), StripeEvent now mandates that this feature be used**. Please set the `signing_secret` configuration value:

```ruby
StripeEvent.signing_secret = Rails.application.secrets.stripe_signing_secret
```

Please refer to Stripe's documentation for more details: https://stripe.com/docs/webhooks#signatures

### Support for multiple signing secrets

Sometimes, you'll have multiple Stripe webhook subscriptions pointing at your application each with a different signing secret. For example, you might have both a main Account webhook and a webhook for a Connect application point at the same endpoint. It's possible to configure an array of signing secrets using the `signing_secrets` configuration option. The first one that successfully matches for each incoming webhook will be used to verify your incoming events.

```ruby
StripeEvent.signing_secrets = [
  Rails.application.secrets.stripe_account_signing_secret,
  Rails.application.secrets.stripe_connect_signing_secret,
]
```

(NOTE: `signing_secret=` and `signing_secrets=` are just aliases for one another)

### Dynamic signing secrets

Both setters also accept a callable returning a secret, an array of secrets, or
`nil`. Arrays may mix static secrets and callables:

```ruby
StripeEvent.signing_secrets = -> { MySecretStore.webhook_secrets }
```

Each callable is evaluated without arguments once per webhook request. The
resolved secrets are reused throughout verification, and refreshed on the next
request. Returning `nil` or an empty array provides no secrets; requests without
any configured secrets are rejected. Errors raised by a provider propagate so
that a temporary secret-store failure does not acknowledge an unprocessed event.

### Routing webhooks by signing source

Use named sources when different webhook endpoints send the same event type to
different handlers. For example, platform and Connect endpoints can share your
Rails webhook URL while retaining separate checkout handlers:

```ruby
StripeEvent.signing_sources = {
  platform: ENV['STRIPE_PLATFORM_SIGNING_SECRET'],
  connect: -> { MySecretStore.connect_webhook_secrets }
}

StripeEvent.configure do |events|
  events.subscribe 'checkout.session.completed',
    Platform::CheckoutSessionCompleted.new, source: :platform

  events.subscribe 'checkout.session.completed',
    Connect::CheckoutSessionCompleted.new, source: :connect

  events.subscribe 'customer.', source: :connect do |event|
    # Handle customer.* events authenticated by the Connect source.
  end

  events.all BillingEventLogger.new(Rails.logger)
  events.all source: :connect do |event|
    # Observe every Connect delivery.
  end
end
```

Source names are nonempty, single-line strings or symbols; `:platform` and
`'platform'` refer to the same source. Source values accept the same strings,
arrays, and callables as `signing_secrets`. Each configured provider is resolved
once per request, before signature verification. A callable takes no arguments.
`nil`, empty arrays, and blank secrets contribute no verification candidates.

The source is selected only after its secret successfully verifies the raw
request body and Stripe signature. Handlers still receive one `Stripe::Event`
argument, with no signing secret added to the event. Sources identify configured
webhook endpoints, not individual connected accounts: use the verified event's
`account` field for merchant identification and authorization. The source is
never inferred from that field.

**Subscription behavior:**

- Subscriptions without `source:` receive matching events from every source,
  including legacy unscoped secrets. Each registration runs once per delivery.
- Subscriptions with `source:` receive only that source's matching events.
  Event-type prefixes, callable objects, blocks, and `all` work in both forms.
- `event_filter` runs once before dispatch. Returning `nil` suppresses both
  global and scoped subscribers; a replacement event is passed to both.
- Global subscribers run before scoped subscribers. Subscriber exceptions
  propagate as before; a global failure can prevent scoped dispatch. Handlers
  must remain idempotent because Stripe can retry deliveries.
- `listening?('checkout.session.completed', source: :platform)` checks global
  and platform listeners, since both would receive that delivery. Without a
  source, it checks only global listeners.

To rotate a secret, associate both secrets with the same source:

```ruby
StripeEvent.signing_sources = {
  platform: [ENV['STRIPE_PLATFORM_SECRET_OLD'], ENV['STRIPE_PLATFORM_SECRET_NEW']],
  connect: ENV['STRIPE_CONNECT_SIGNING_SECRET']
}
```

The first successful verification selects the source and dispatches once, even
if multiple rotation signatures match. On an unrestricted mount, assigning the same secret to different
sources raises `ArgumentError` before verification, as does sharing a secret
between a named source and legacy `signing_secrets`. A fixed-source mount can
use shared secrets as described below. Provider failures also
propagate without dispatch. No usable secrets or an invalid signature results
in the existing HTTP 400 response.

When migrating, **move** each secret out of `signing_secrets` into its named
source and replace the corresponding subscriptions with scoped ones. Distinct
legacy secrets may coexist with named sources and reach only global subscribers.
The `signing_secrets` getter continues to return only legacy secrets. Assigning
`signing_sources = nil` clears named sources without changing legacy secrets.

For tests or non-Rails integrations, explicitly supply the source after verifying
the signature yourself:

```ruby
StripeEvent.instrument(verified_event, source: :platform)
```

Calling `instrument(event)` without a source reaches only global subscribers.
Instrumentation itself does not authenticate events or verify that a supplied
source has configured secrets.

Internally, the existing global notification name and Stripe event payload are
preserved. Scoped delivery uses a separate `stripe_event_source:` notification
namespace with the same payload and adapter interface. Custom notification
consumers should use the public subscription API to avoid observing both streams;
custom global namespaces should not overlap that reserved prefix.

### Separate webhook URLs for platform and Connect events

A marketplace might use its platform Stripe account to bill sellers for their
subscriptions, while connected accounts take payments for customer orders. Both
flows can emit `checkout.session.completed`, but completing a seller's
subscription and fulfilling a customer order require different handlers.

Named sources let these flows share a URL. If you prefer each URL to express its
purpose, mount the engine twice with a `stripe_event_source` route default:

```ruby
# config/routes.rb
mount StripeEvent::Engine,
  at: '/webhooks/stripe/platform',
  as: :stripe_platform,
  defaults: { stripe_event_source: 'platform' }

mount StripeEvent::Engine,
  at: '/webhooks/stripe/connect',
  as: :stripe_connect,
  defaults: { stripe_event_source: 'connect' }
```

Give each mount a unique `as:` name. Configure the matching signing sources and
handlers in your initializer:

```ruby
# config/initializers/stripe.rb
StripeEvent.signing_sources = {
  platform: ENV['STRIPE_PLATFORM_SIGNING_SECRET'],
  connect: ENV['STRIPE_CONNECT_SIGNING_SECRET']
}

StripeEvent.configure do |events|
  events.subscribe 'checkout.session.completed',
    SellerSubscriptionCompleted.new, source: :platform

  events.subscribe 'checkout.session.completed',
    CustomerOrderCompleted.new, source: :connect

  events.all BillingEventLogger.new(Rails.logger)
end
```

In Stripe, configure the platform webhook endpoint to send events to
`https://your-app.example/webhooks/stripe/platform` and the connected-account
endpoint to send events to `https://your-app.example/webhooks/stripe/connect`.
Use each endpoint's signing secret for its matching source.

The platform URL verifies only platform secrets and the Connect URL verifies
only Connect secrets. Posting a Connect-signed event to the platform URL (or the
reverse) returns HTTP 400 without calling any subscribers. An unknown source or
one without usable secrets is also rejected, with no fallback to other sources.
String and symbol source names are equivalent. Rotation arrays and callable
providers work as described above.

The route default restricts which secrets may authenticate a request; it does
not bypass signature verification. Only `request.path_parameters` is consulted,
so query-string and JSON body fields cannot override the configured source.
Keep this value in fixed route defaults, not a user-supplied URL segment.

Mounts still share StripeEvent's configuration, event filter, and subscriptions.
Global subscribers receive each accepted delivery once, alongside the matching
source's subscribers. All configured secret providers are still resolved once
per request. Candidates are then restricted to the mount before checking for
ambiguous secrets. A provider failure in another source therefore still fails the
request; separate mounts do not provide independent provider availability.

A mount without `stripe_event_source` continues to accept every configured
source, including legacy unscoped secrets. You can retain such a shared mount
alongside the restricted URLs during migration. Query or body parameters cannot
add a source restriction to the shared mount either. When moving secrets to
named sources, remove their entries from legacy `signing_secrets` as described
above.

### Stripe CLI with a shared signing secret

Stripe CLI uses one signing secret for both platform and Connect deliveries.
With the two fixed-source mounts above, assign that secret to both named sources:

```ruby
StripeEvent.signing_secrets = []
StripeEvent.signing_sources = {
  platform: ENV['STRIPE_CLI_SIGNING_SECRET'],
  connect: ENV['STRIPE_CLI_SIGNING_SECRET']
}
```

```sh
stripe listen --forward-to localhost:3000/webhooks/stripe/platform \
  --forward-connect-to localhost:3000/webhooks/stripe/connect
```

Each URL verifies the signature against its configured source and dispatches
only that source's subscribers (plus global subscribers). The fixed route
provides the source distinction: with a shared secret, the signature alone cannot
distinguish platform from Connect. Payload fields still cannot choose the source.
Use distinct Dashboard endpoint secrets in deployed environments when you need
cryptographic separation between sources. Handlers should independently validate
merchant ownership and the event's expected account scope.

An unrestricted/shared mount still rejects duplicate secrets with `ArgumentError`,
including when query or body parameters attempt to select a source. Wrong signatures,
unknown sources and sources without usable secrets remain rejected. All callable
providers are still resolved once; a failure in another source still propagates.

## Configuration

If you have built an application that has multiple Stripe accounts--say, each of your customers has their own--you may want to define your own way of retrieving events from Stripe (e.g. perhaps you want to use the [account parameter](https://stripe.com/docs/connect/webhooks) from the top level to detect the customer for the event, then grab their specific API key). You can do this:

```ruby
class EventFilter
  def call(event)
    event.api_key = lookup_api_key(event.account)
    event
  end

  def lookup_api_key(account_id)
    Account.find_by!(stripe_account_id: account_id).api_key
  rescue ActiveRecord::RecordNotFound
    # whoops something went wrong - error handling
  end
end

StripeEvent.event_filter = EventFilter.new
```

If you'd like to ignore particular webhook events (perhaps to ignore test webhooks in production, or to ignore webhooks for a non-paying customer), you can do so by returning `nil` in your custom `event_filter`. For example:

```ruby
StripeEvent.event_filter = lambda do |event|
  return nil if Rails.env.production? && !event.livemode
  event
end
```

```ruby
StripeEvent.event_filter = lambda do |event|
  account = Account.find_by!(stripe_account_id: event.account)
  return nil if account.delinquent?
  event
end
```

*Note: Older versions of Stripe used `event.user_id` to reference the Connect Account ID.*

## Without Rails

StripeEvent can be used outside of Rails applications as well. Here is a basic Sinatra implementation:

```ruby
require 'json'
require 'sinatra'
require 'stripe_event'

Stripe.api_key = ENV['STRIPE_SECRET_KEY']

StripeEvent.subscribe 'charge.failed' do |event|
  # Look ma, no Rails!
end

post '/_billing_events' do
  data = JSON.parse(request.body.read, symbolize_names: true)
  StripeEvent.instrument(data)
  200
end
```

## Testing

Handling webhooks is a critical piece of modern billing systems. Verifying the behavior of StripeEvent subscribers can be done fairly easily by stubbing out the HTTP signature header used to authenticate the webhook request. Tools like [Webmock](https://github.com/bblimke/webmock) and [VCR](https://github.com/vcr/vcr) work well. [RequestBin](https://requestbin.com/) is great for collecting the payloads. For exploratory phases of development, [UltraHook](http://www.ultrahook.com/) and other tools can forward webhook requests directly to localhost. You can check out [test-hooks](https://github.com/invisiblefunnel/test-hooks), an example Rails application to see how to test StripeEvent subscribers with RSpec request specs and Webmock. A quick look:

```ruby
# spec/requests/billing_events_spec.rb
require 'rails_helper'

describe "Billing Events" do
  def bypass_event_signature(payload)
    event = Stripe::Event.construct_from(JSON.parse(payload, symbolize_names: true))
    expect(Stripe::Webhook).to receive(:construct_event).and_return(event)
  end

  describe "customer.created" do
    let(:payload) { file_fixture('evt_customer_created.json').read }
    before(:each) { bypass_event_signature(payload) }

    it "is successful" do
      post '/_billing_events', params: payload
      expect(response).to have_http_status(:success)
      # Additional expectations...
    end
  end
end
```

### Maintainers

* [Ryan McGeary](https://github.com/rmm5t)
* [Pete Keen](https://github.com/peterkeen)
* [Danny Whalen](https://github.com/invisiblefunnel)

Special thanks to all the [contributors](https://github.com/integrallis/stripe_event/graphs/contributors).

### Versioning

Semantic Versioning 2.0 as defined at <http://semver.org>.

### License

[MIT License](https://github.com/integrallis/stripe_event/blob/master/LICENSE.md). Copyright 2012-2015 Integrallis Software.
