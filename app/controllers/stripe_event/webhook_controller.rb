module StripeEvent
  class WebhookController < ActionController::Base
    def event
      @event = Stripe::Event.retrieve(params[:id])
      StripeEvent.publish(@event)
      head :ok
    rescue Stripe::StripeError
      head :unauthorized
    end
  end
end
