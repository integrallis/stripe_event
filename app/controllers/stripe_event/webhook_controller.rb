module StripeEvent
  class WebhookController < ActionController::Base
    if respond_to?(:before_action)
      before_action :request_authentication
      before_action :verify_signature
    else
      before_filter :request_authentication
      before_filter :verify_signature
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

    def request_authentication
      if StripeEvent.authentication_secret
        authenticate_or_request_with_http_basic do |username, password|
          ActiveSupport::SecurityUtils.variable_size_secure_compare password, StripeEvent.authentication_secret
        end
      end
    end

    def verify_signature
      if StripeEvent.signing_secret
        payload   = request.body.read
        signature = request.headers['Stripe-Signature']

        Stripe::Webhook::Signature.verify_header payload, signature, StripeEvent.signing_secret
      end
    rescue Stripe::SignatureVerificationError
      head :bad_request
    end
  end
end
