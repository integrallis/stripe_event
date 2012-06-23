StripeEvent::Engine.routes.draw do
  root :to => 'webhook#event'
end
