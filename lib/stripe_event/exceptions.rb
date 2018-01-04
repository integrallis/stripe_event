module StripeEvent
  Error = Class.new(StandardError)

  UnauthorizedError = Class.new(Error)
end
