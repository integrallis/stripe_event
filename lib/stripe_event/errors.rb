module StripeEvent
  class StripeEventError < StandardError; end
  class InvalidEventTypeError < StripeEventError; end
end
