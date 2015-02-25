# StripeEvent
[![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.svg)](http://travis-ci.org/integrallis/stripe_event) [![Dependency Status](https://gemnasium.com/integrallis/stripe_event.svg)](https://gemnasium.com/integrallis/stripe_event) [![Gem Version](https://badge.fury.io/rb/stripe_event.svg)](http://badge.fury.io/rb/stripe_event) [![Code Climate](https://codeclimate.com/github/integrallis/stripe_event.svg)](https://codeclimate.com/github/integrallis/stripe_event) [![Coverage Status](https://coveralls.io/repos/integrallis/stripe_event/badge.svg)](https://coveralls.io/r/integrallis/stripe_event)

StripeEvent is built on the [ActiveSupport::Notifications API](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html). Incoming webhook requests are authenticated by [retrieving the event object](https://stripe.com/docs/api?lang=ruby#retrieve_event) from Stripe. Define subscribers to handle specific event types. Subscribers can be a block or an object that responds to `#call`.

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
Stripe.api_key = ENV['STRIPE_API_KEY'] # Set your api key

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

StripeEvent automatically fetches events from Stripe to ensure they haven't been forged. However, that doesn't prevent an attacker who knows your endpoint name and an event's ID from forcing your server to process a legitimate event twice. If that event triggers some useful action, like generating a license key or enabling a delinquent account, you could end up giving something the attacker is supposed to pay for away for free.

To prevent this, StripeEvent supports using HTTP Basic authentication on your webhook endpoint. If only Stripe knows the basic authentication password, this ensures that the request really comes from Stripe. Here's what you do:

1. Arrange for a secret key to be available in your application's environment variables or `secrets.yml` file. You can generate a suitable secret with the `rake secret` command. (Remember, the `secrets.yml` file shouldn't contain production secrets directly; it should use ERB to include them.)

2. Configure StripeEvent to require that secret be used as a basic authentication password, using code along the lines of these examples:

    ```ruby
    # STRIPE_WEBHOOK_SECRET environment variable
    StripeEvent.authentication_secret = ENV['STRIPE_WEBHOOK_SECRET']
    # stripe_webhook_secret key in secrets.yml file
    StripeEvent.authentication_secret = Rails.application.secrets.stripe_webhook_secret
    ```

3. When you specify your webhook's URL in Stripe's settings, include the secret as a password in the URL, along with any username:

        https://stripe:my-secret-key@myapplication.com/my-webhook-path

This is only truly secure if your webhook endpoint is accessed over SSL, which Stripe strongly recommends anyway.

## Configuration

If you have built an application that has multiple Stripe accounts--say, each of your customers has their own--you may want to define your own way of retrieving events from Stripe (e.g. perhaps you want to use the [user_id parameter](https://stripe.com/docs/apps/getting-started#webhooks) from the top level to detect the customer for the event, then grab their specific API key). You can do this:

```ruby
StripeEvent.event_retriever = lambda do |params|
  api_key = Account.find_by!(stripe_user_id: params[:user_id]).api_key
  Stripe::Event.retrieve(params[:id], api_key)
end
```

```ruby
class EventRetriever
  def call(params)
    api_key = retrieve_api_key(params[:user_id])
    Stripe::Event.retrieve(params[:id], api_key)
  end

  def retrieve_api_key(stripe_user_id)
    Account.find_by!(stripe_user_id: stripe_user_id).api_key
  rescue ActiveRecord::RecordNotFound
    # whoops something went wrong - error handling
  end
end

StripeEvent.event_retriever = EventRetriever.new
```

If you'd like to ignore particular webhook events (perhaps to ignore test webhooks in production, or to ignore webhooks for a non-paying customer), you can do so by returning `nil` in you custom `event_retriever`. For example:

```ruby
StripeEvent.event_retriever = lambda do |params|
  return nil if Rails.env.production? && !params[:livemode]
  Stripe::Event.retrieve(params[:id])
end
```

```ruby
StripeEvent.event_retriever = lambda do |params|
  account = Account.find_by!(stripe_user_id: params[:user_id])
  return nil if account.delinquent?
  Stripe::Event.retrieve(params[:id], account.api_key)
end
```

## Without Rails

StripeEvent can be used outside of Rails applications as well. Here is a basic Sinatra implementation:

```ruby
require 'json'
require 'sinatra'
require 'stripe_event'

Stripe.api_key = ENV['STRIPE_API_KEY']

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

Handling webhooks is a critical piece of modern billing systems. Verifying the behavior of StripeEvent subscribers can be done fairly easily by stubbing out the HTTP request used to authenticate the webhook request. Tools like [Webmock](https://github.com/bblimke/webmock) and [VCR](https://github.com/vcr/vcr) work well. [RequestBin](http://requestb.in/) is great for collecting the payloads. For exploratory phases of development, [UltraHook](http://www.ultrahook.com/) and other tools can forward webhook requests directly to localhost. You can check out [test-hooks](https://github.com/invisiblefunnel/test-hooks), an example Rails application to see how to test StripeEvent subscribers with RSpec request specs and Webmock. A quick look:

```ruby
# spec/requests/billing_events_spec.rb
require 'spec_helper'

describe "Billing Events" do
  def stub_event(fixture_id, status = 200)
    stub_request(:get, "https://api.stripe.com/v1/events/#{fixture_id}").
      to_return(status: status, body: File.read("spec/support/fixtures/#{fixture_id}.json"))
  end

  describe "customer.created" do
    before do
      stub_event 'evt_customer_created'
    end

    it "is successful" do
      post '/_billing_events', id: 'evt_customer_created'
      expect(response.code).to eq "200"
      # Additional expectations...
    end
  end
end
```

### Note: 'Test Webhooks' Button on Stripe Dashboard

This button sends an example event to your webhook urls, including an `id` of `evt_00000000000000`. To confirm that Stripe sent the webhook, StripeEvent attempts to retrieve the event details from Stripe using the given `id`. In this case the event does not exist and StripeEvent responds with `401 Unauthorized`. Instead of using the 'Test Webhooks' button, trigger webhooks by using the Stripe API or Dashboard to create test payments, customers, etc.

### Maintainers

* [Ryan McGeary](https://github.com/rmm5t)
* [Pete Keen](https://github.com/peterkeen)
* [Danny Whalen](https://github.com/invisiblefunnel)

Special thanks to all the [contributors](https://github.com/integrallis/stripe_event/graphs/contributors).

### License

[MIT License](https://github.com/integrallis/stripe_event/blob/master/LICENSE.md). Copyright 2012-2015 Integrallis Software.
