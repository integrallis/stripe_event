Rails.application.routes.draw do
  mount StripeEvent::Engine => "/stripe_event"
end
