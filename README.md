# StripeEvent [![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)](http://travis-ci.org/integrallis/stripe_event) [![Dependency Status](https://gemnasium.com/integrallis/stripe_event.png)](https://gemnasium.com/integrallis/stripe_event) [![Gem Version](https://badge.fury.io/rb/stripe_event.png)](http://badge.fury.io/rb/stripe_event)

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

StripeEvent.setup do
  subscribe 'charge.failed' do |event|
    # Define subscriber behavior based on the event object
    event.class       #=> Stripe::Event
    event.type        #=> "charge.failed"
    event.data.object #=> #<Stripe::Charge:0x3fcb34c115f8> JSON: { ... }
  end

  all do |event|
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
    @logger = logger || Logger.new($stdout)
  end

  def call(event)
    @logger.info "BILLING-EVENT: #{event.type} #{event.id}"
  end
end

StripeEvent.setup do
  all BillingEventLogger.new(Rails.logger)
  subscribe 'customer.created', CustomerCreated.new
end
```

## Configuration

If you have built an application that has multiple Stripe accounts--say, each of your customers has their own--you may want to define your own way of retrieving events from Stripe (e.g. perhaps you want to use the [user_id parameter](https://stripe.com/docs/apps/getting-started#webhooks) from the top level to detect the customer for the event, then grab their specific API key). You can do this:

```ruby
StripeEvent.event_retriever = lambda do |params|
  secret_key = Account.find_by_stripe_user_id(params[:user_id]).secret_key
  Stripe::Event.retrieve(params[:id], secret_key)
end
```

### Register webhook url with Stripe

![Setup webhook url](https://raw.github.com/integrallis/stripe_event/master/dashboard-webhook.png "webhook setup")

### Examples

The [RailsApps](https://github.com/RailsApps) project by Daniel Kehoe has released an [example Rails 3.2 app](https://github.com/RailsApps/rails-stripe-membership-saas) with recurring billing using Stripe. The application uses StripeEvent to handle `customer.subscription.deleted` events.

### Note: 'Test Webhooks' Button on Stripe Dashboard

This button sends an example event to your webhook urls, including an `id` of `evt_00000000000000`. To confirm that Stripe sent the webhook, StripeEvent attempts to retrieve the event details from Stripe using the given `id`. In this case the event does not exist and StripeEvent responds with `401 Unauthorized`. Instead of using the 'Test Webhooks' button, trigger webhooks by using the Stripe API or Dashboard to create test payments, customers, etc.

### License

[MIT License](https://github.com/integrallis/stripe_event/blob/master/LICENSE.md). Copyright 2012-2013 Integrallis Software.
