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
    rescue StripeEvent::UnauthorizedError => e
      log_error(e)
      head :unauthorized
    end

    private

    def log_error(e)
      logger.error e.message
      e.backtrace.each { |line| logger.error "  #{line}" }
    end
  end
end
