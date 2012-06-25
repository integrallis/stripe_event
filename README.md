stripe_event
============

stripe_event is built on the ActiveSupport::Notifications API. Incoming webhook requests are authenticated by retrieving the event from Stripe. The retrieved event is yielded to subscribers when published.

```ruby
# Gemfile
gem 'stripe_event'
```

```ruby
# config/routes.rb
mount StripeEvent::Engine => "/stripe_event"
```

```ruby
# config/initializers/stripe.rb
Stripe.api_key = ENV['STRIPE_API_KEY'] # Set your api key

# Define subscriber behavior
StripeEvent.subscribe 'charge.failed' do |event|
  MyClass.handle_failed_charge(event)
end
```
