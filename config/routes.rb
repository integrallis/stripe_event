StripeEvent::Engine.routes.draw do
  root to: 'webhook#event', via: :post
end
