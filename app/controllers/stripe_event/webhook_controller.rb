module StripeEvent
  class WebhookController < ApplicationController
    def event
      StripeEvent.publish(@event)
      head :ok
    end
  end
end
