module StripeEvent
  class WebhookController < ActionController::Base
    def event
      event = StripeEvent.event_retriever.call(params)
      StripeEvent.publish(event)
      head :ok
    rescue Stripe::StripeError
      head :unauthorized
    end
  end
end
