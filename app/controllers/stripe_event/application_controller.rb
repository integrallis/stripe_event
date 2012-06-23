module StripeEvent
  class ApplicationController < ActionController::Base
    
    # Authentication
    before_filter do
      begin
        @event = Stripe::Event.retrieve(params[:id])
      rescue Stripe::StripeError
        head :unauthorized
      end
    end
    
  end
end
