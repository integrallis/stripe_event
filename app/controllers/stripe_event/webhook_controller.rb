module StripeEvent
  class WebhookController < ApplicationController
    def event
      head :ok
    end
  end
end
