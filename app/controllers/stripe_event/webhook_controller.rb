module StripeEvent
  class WebhookController < ActionController::Base
    def event
      StripeEvent.instrument(verified_event)
      head :ok
    rescue Stripe::SignatureVerificationError => e
      log_error(e)
      head :bad_request
    end

    private

    def verified_event
      payload   = request.body.read
      signature = request.headers['Stripe-Signature']
      Stripe::Webhook.construct_event(payload, signature, StripeEvent.signing_secret.to_s)
    end

    def log_error(e)
      logger.error e.message
      e.backtrace.each { |line| logger.error "  #{line}" }
    end
  end
end
