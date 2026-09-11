Rails.application.routes.draw do
  mount StripeEvent::Engine => "/webhooks/stripe/platform", as: :stripe_platform,
    defaults: { stripe_event_source: :platform }
  mount StripeEvent::Engine => "/webhooks/stripe/connect", as: :stripe_connect,
    defaults: { stripe_event_source: 'connect' }
  mount StripeEvent::Engine => "/stripe_event"
end
