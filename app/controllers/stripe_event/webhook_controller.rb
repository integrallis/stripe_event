module StripeEvent
  class WebhookController < ActionController::Base
    before_filter do
      StripeEvent.authentication_secret.nil? or \
        authenticate_or_request_with_http_basic do |username, password|
          password == StripeEvent.authentication_secret
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
