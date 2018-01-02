module StripeEvent
  class NotificationAdapter
    attr_accessor :subscriber

    def self.call(callable)
      new(callable)
    end

    def initialize(subscriber)
      @subscriber = subscriber
    end

    def call(*args)
      payload = args.last
      subscriber.call(payload)
    end
  end
end
