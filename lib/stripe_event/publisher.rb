module StripeEvent
  class Publisher < Struct.new(:event)
    def instrument
      ActiveSupport::Notifications.instrument(type, event)
    end

    def type
      return event[:type] if event[:type].present?
      raise InvalidEventTypeError.new("Event type was not present for: #{event}")
    end
  end
end
