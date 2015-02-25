module StripeEvent
  class WebhookController < ActionController::Base
    before_filter do
      if StripeEvent.authentication_secret
        authenticate_or_request_with_http_basic do |username, password|
          password == StripeEvent.authentication_secret
        end
      end
    end
    
    def event
      StripeEvent.instrument(params)
      head :ok
    rescue StripeEvent::UnauthorizedError
      head :unauthorized
    end
  end
end
