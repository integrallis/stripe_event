## stripe_event

[![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)](http://travis-ci.org/integrallis/stripe_event)

stripe_event is built on the ActiveSupport::Notifications API. Incoming webhook requests are authenticated by retrieving the [event object](https://stripe.com/docs/api?lang=ruby#event_object) from Stripe. Define subscriber blocks to handle one, many, or all event types.

## Install

```ruby
# Gemfile
gem 'stripe_event'
```

```ruby
# config/routes.rb
mount StripeEvent::Engine => "/my-chosen-path" # provide a custom path
```

## Usage

```ruby
# config/initializers/stripe.rb
Stripe.api_key = ENV['STRIPE_API_KEY'] # Set your api key

StripeEvent.configure do
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

## Note: The "Test Webhooks" Button Doesn't Work

![Test Webhooks Fails](https://raw.github.com/barancw/stripe_event/master/screenshots/dashboard-webhook-test-fail.png "test webhooks fails")

This implementation increases security by fetching the sent event again from stripe and eliminating any man in the middle or spoof attacks.  Unfortunately this breaks the test button from this panel.  If you need to test your setup make sure to trigger real events from your test site.  These events will all load correctly.
