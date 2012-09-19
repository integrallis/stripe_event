## stripe_event

[![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)](http://travis-ci.org/integrallis/stripe_event)

stripe_event is built on the ActiveSupport::Notifications API[[0]](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html). Incoming webhook requests are authenticated by retrieving the [event object](https://stripe.com/docs/api?lang=ruby#event_object) from Stripe[[1]](https://answers.stripe.com/questions/what-is-the-recommended-way-to-authenticate-a-webhook-callback). Define subscriber blocks to handle one, many, or all event types.

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

## Configuration

If you have built an application that has multiple Stripe accounts--say, each of your customers has their own--you may want to define your own way of retrieving events from Stripe (e.g. perhaps you want to use the `user_id` paramter from the top level to detect the customer for the event, then grab their specific API key). You can do this:

```ruby
StripeEvent.event_retriever = Proc.new do |params| 
  secret_key = Account.find_by_stripe_user_id(params[:user_id]).secret_key
  Stripe::Event.retrieve(params[:id], secret_key)
end
```

## Register webhook url with Stripe

![Setup webhook url](https://raw.github.com/integrallis/stripe_event/master/screenshots/dashboard-webhook.png "webhook setup")
