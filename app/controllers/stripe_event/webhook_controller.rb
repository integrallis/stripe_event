module StripeEvent
  class WebhookController < ActionController::Base
    def event
      StripeEvent.instrument(params)
      head :ok
    rescue StripeEvent::UnauthorizedError
      head :unauthorized
    end
  end
end
