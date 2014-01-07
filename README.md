# StripeEvent
[![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)](http://travis-ci.org/integrallis/stripe_event) [![Dependency Status](https://gemnasium.com/integrallis/stripe_event.png)](https://gemnasium.com/integrallis/stripe_event) [![Gem Version](https://badge.fury.io/rb/stripe_event.png)](http://badge.fury.io/rb/stripe_event) [![Code Climate](https://codeclimate.com/github/integrallis/stripe_event.png)](https://codeclimate.com/github/integrallis/stripe_event)

StripeEvent is built on the [ActiveSupport::Notifications API](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html). Incoming webhook requests are authenticated by [retrieving the event object](https://stripe.com/docs/api?lang=ruby#retrieve_event) from Stripe. Define subscribers to handle a single event type or all event types. Subscribers can be a block or any object that responds to `#call`.

## Install

```ruby
# Gemfile
gem 'stripe_event'
```

```ruby
# config/routes.rb
mount StripeEvent::Engine => '/my-chosen-path' # provide a custom path
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

# Subscriber objects that respond to #call

class CustomerCreated
  def call(event)
    # Event handling
  end
end

class BillingEventLogger
  def initialize(logger = nil)
    @logger = logger || begin
      require 'logger'
      Logger.new($stdout)
    end
  end

  def call(event)
    @logger.info "BILLING-EVENT: #{event.type} #{event.id}"
  end
end

StripeEvent.configure do |events|
  events.all BillingEventLogger.new(Rails.logger)
  events.subscribe 'customer.created', CustomerCreated.new
end

# Subscribing to a namespace of event types

StripeEvent.subscribe 'customer.card.' do |event|
  # Will be triggered for any customer.card.* events
end
```

## Configuration

If you have built an application that has multiple Stripe accounts--say, each of your customers has their own--you may want to define your own way of retrieving events from Stripe (e.g. perhaps you want to use the [user_id parameter](https://stripe.com/docs/apps/getting-started#webhooks) from the top level to detect the customer for the event, then grab their specific API key). You can do this:

```ruby
StripeEvent.event_retriever = lambda do |params|
  api_key = Account.find_by!(stripe_user_id: params[:user_id]).api_key
  Stripe::Event.retrieve(params[:id], api_key)
end

# Or use any object that responds to #call

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

Handling webhooks is a critical piece of modern billing systems. Verifying the behavior of StripeEvent subscribers can be done fairly easily by stubbing out the HTTP request used to authenticate the webhook request. Tools like [Webmock](https://github.com/bblimke/webmock) and [VCR](https://github.com/vcr/vcr) work well. [RequestBin](http://requestb.in/) is great for collecting the payloads. For exploratory phases of development, [UltraHook](http://www.ultrahook.com/) and other tools can forward webhook requests directly to localhost. You can check out [test-hooks](https://github.com/invisiblefunnel/test-hooks), and example Rails application to see how to test StripeEvent subscribers with RSpec request specs and Webmock. A quick look:

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

### License

[MIT License](https://github.com/integrallis/stripe_event/blob/master/LICENSE.md). Copyright 2012-2013 Integrallis Software.
