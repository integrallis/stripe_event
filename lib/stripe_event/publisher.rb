module StripeEvent
  class Publisher < Struct.new(:event)
    def instrument
      ActiveSupport::Notifications.instrument(type, event)
    end
    
    def type
      event[:type].tap { |type|
        raise InvalidEventTypeError.new("Event type was not present for: #{event}") if !type.present?
      }
    end
  end
end
