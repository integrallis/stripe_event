module StripeEvent
  class WebhookController < ActionController::Base
    def event
      StripeEvent.instrument(params)
      head :ok
    rescue Stripe::StripeError
      head :unauthorized
    end
  end
end
