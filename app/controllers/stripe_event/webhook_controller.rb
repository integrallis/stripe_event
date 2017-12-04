module StripeEvent
  class WebhookController < ActionController::Base
    if respond_to?(:before_action)
      before_action :verify_signature
    else
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

    def verify_signature
      if StripeEvent.signing_secret
        payload   = request.body.read
        signature = request.headers['Stripe-Signature']

        Stripe::Webhook::Signature.verify_header payload, signature, StripeEvent.signing_secret
      else
        ActiveSupport::Deprecation.warn(
        "[STRIPE_EVENT] Unverified use of stripe webhooks is deprecated and configuration of " +
        "`StripeEvent.signing_secret=` will be required in 2.x. The value for your specific " +
        "endpoint's signing secret (starting with `whsec_`) is in your API > Webhooks settings " +
        "(https://dashboard.stripe.com/account/webhooks). " +
        "More information can be found here: https://stripe.com/docs/webhooks#signatures")
      end
    rescue Stripe::SignatureVerificationError
      head :bad_request
    end
  end
end
