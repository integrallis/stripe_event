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
      secret    = sniff_signing_secret(payload, signature)
      Stripe::Webhook.construct_event(payload, signature, secret.to_s)
    end

    def sniff_signing_secret(payload, signature)
      return StripeEvent.signing_secret unless multiple_signing_secrets?

      StripeEvent.signing_secrets.each do |secret|
        begin
          Stripe::Webhook::Signature.verify_header payload, signature, secret
          return secret
        rescue Stripe::SignatureVerificationError
          next
        end
      end

      return nil
    end

    def multiple_signing_secrets?
      StripeEvent.signing_secrets && StripeEvent.signing_secrets.length > 1
    end

    def log_error(e)
      logger.error e.message
      e.backtrace.each { |line| logger.error "  #{line}" }
    end
  end
end
