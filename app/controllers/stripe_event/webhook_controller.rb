module StripeEvent
  class WebhookController < ApplicationController
    skip_before_filter :verify_authenticity_token, :if => :xml_request?

    # Authentication
    before_filter do
      begin
        @event = Stripe::Event.retrieve(params[:id])
      rescue Stripe::StripeError
        head :unauthorized
      end
    end

    def event
      StripeEvent.publish(@event)
      head :ok
    end

    protected

    def xml_request?
      request.format.xml?
    end
  end
end
