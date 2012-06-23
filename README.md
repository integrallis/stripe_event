stripe_event
============

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

# Set your api key
Stripe.api_key = ENV['STRIPE_API_KEY']

StripeEvent.configure do |config|

  # Define subscriber behavior
  config.subscribe 'charge.failed' do |event|
    MyClass.handle_failed_charge(event)
  end

end
```
