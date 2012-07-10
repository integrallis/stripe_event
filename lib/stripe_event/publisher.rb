module StripeEvent
  class Publisher
    def initialize(event)
      @event = event
    end
    
    def publish
      ActiveSupport::Notifications.instrument(@event.type, :event => @event)
    end
  end
end
