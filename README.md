## stripe_event

[![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)](http://travis-ci.org/integrallis/stripe_event)

stripe_event is built on the ActiveSupport::Notifications API. Incoming webhook requests are authenticated by retrieving the [event object](https://stripe.com/docs/api?lang=ruby#event_object) from Stripe. Authenticated events are published to subscribers.

## Install


```ruby
# Gemfile
gem 'stripe_event'
```

```ruby
# config/routes.rb
mount StripeEvent::Engine => "/stripe_event" # or provide a custom path
```

## Usage

```ruby
# config/initializers/stripe.rb
Stripe.api_key = ENV['STRIPE_API_KEY'] # Set your api key

StripeEvent.registration do

  subscribe 'charge.failed' do |event|
    MyClass.handle_failed_charge(event) # Define subscriber behavior
  end

  subscribe 'customer.created', 'customer.updated' do |event|
    # Handle multiple event types
  end

  subscribe do |event|
    # Handle all event types - logging, etc.
  end

end
```

## Register webhook url with Stripe

![Setup webhook url](https://raw.github.com/integrallis/stripe_event/master/screenshots/dashboard-webhook.png "webhook setup")
