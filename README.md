## stripe_event

[![Build Status](https://secure.travis-ci.org/integrallis/stripe_event.png?branch=master)](http://travis-ci.org/integrallis/stripe_event)

stripe_event is built on the [ActiveSupport::Notifications API](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html). Incoming webhook requests are authenticated by retrieving the [event object](https://stripe.com/docs/api?lang=ruby#event_object) from Stripe[[1]](https://answers.stripe.com/questions/what-is-the-recommended-way-to-authenticate-a-webhook-callback). Define subscriber blocks to handle one, many, or all event types.

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
    event.class #=> Stripe::Event
    event.type  #=> "charge.failed"
    event.data  #=> { ... }
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

If you have built an application that has multiple Stripe accounts--say, each of your customers has their own--you may want to define your own way of retrieving events from Stripe (e.g. perhaps you want to use the [user_id parameter](https://stripe.com/docs/apps/getting-started#webhooks) from the top level to detect the customer for the event, then grab their specific API key). You can do this:

```ruby
StripeEvent.event_retriever = Proc.new do |params| 
  secret_key = Account.find_by_stripe_user_id(params[:user_id]).secret_key
  Stripe::Event.retrieve(params[:id], secret_key)
end
```

During development it may be useful to skip retrieving the event from Stripe, and deal with the params hash directly. Just remember that the data has not been authenticated.

```ruby
StripeEvent.event_retriever = Proc.new { |params| params }
```

### Register webhook url with Stripe

![Setup webhook url](https://raw.github.com/integrallis/stripe_event/master/screenshots/dashboard-webhook.png "webhook setup")

### Examples

The [RailsApps](https://github.com/RailsApps) project by Daniel Kehoe has released an [example Rails 3.2 app](https://github.com/RailsApps/rails-stripe-membership-saas) with recurring billing using Stripe. The application uses stripe_event to handle `customer.subscription.deleted` events.

### Note: 'Test Webhooks' Button on Stripe Dashboard

This button sends an example event to your webhook urls, including an `id` of `evt_00000000000000`. To confirm that Stripe sent the webhook, stripe_event attempts to retrieve the event details from Stripe using the given `id`. In this case the event does not exist and stripe_event responds with `401 Unauthorized`. Instead of using the 'Test Webhooks' button, trigger webhooks by using the Stripe Dashboard to create test payments, customers, etc.
