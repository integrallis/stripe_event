## stripe_event [![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)][travis]

stripe_event is built on the ActiveSupport::Notifications API. Incoming webhook requests are authenticated by retrieving the event from Stripe. Authenticated events are published to subscribers.

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

# Define subscriber behavior
StripeEvent.subscribe 'charge.failed' do |event|
  MyClass.handle_failed_charge(event)
end
```

## Register webhook url with Stripe

![Setup webhook url](https://raw.github.com/integrallis/stripe_event/master/screenshots/dashboard-webhook.png "webhook setup")
