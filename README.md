# StripeEvent

[![Build Status](https://github.com/integrallis/stripe_event/workflows/CI/badge.svg)](https://github.com/integrallis/stripe_event/actions?query=workflow%3ACI)
[![Gem Version](https://badge.fury.io/rb/stripe_event.svg)](http://badge.fury.io/rb/stripe_event)
[![Code Climate](https://codeclimate.com/github/integrallis/stripe_event.svg)](https://codeclimate.com/github/integrallis/stripe_event)
[![Coverage Status](https://coveralls.io/repos/integrallis/stripe_event/badge.svg)](https://coveralls.io/r/integrallis/stripe_event)
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
