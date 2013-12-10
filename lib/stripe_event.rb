require "active_support/notifications"
require "stripe"
require "stripe_event/engine" if defined?(Rails)

module StripeEvent
  class << self
    attr_accessor :backend, :event_retriever, :namespace

    def setup(&block)
      instance_eval(&block)
    end

    def instrument(params)
      begin
        event = event_retriever.call(params)
      rescue Stripe::StripeError => e
        raise UnauthorizedError.new(e)
      end

      publish event
    end

    def publish(event)
      backend.publish namespace.call(event[:type]), event
    end

    def subscribe(name, callable = Proc.new)
      backend.subscribe namespace.to_regexp(name), NotificationAdapter.new(callable)
    end

    def all(callable = Proc.new)
      subscribe nil, callable
    end
  end

  class Namespace < Struct.new(:value, :delimiter)
    def call(name = nil)
      name ? "#{value}#{delimiter}#{name}" : value
    end

    def to_regexp(name = nil)
      %r{^#{call(name)}}
    end
  end

  class NotificationAdapter < Struct.new(:subscriber)
    def call(*args)
      payload = args.last
      subscriber.call(payload)
    end
  end

  class UnauthorizedError < StandardError; end

  self.backend = ActiveSupport::Notifications
  self.event_retriever = lambda { |params| Stripe::Event.retrieve(params[:id]) }
  self.namespace = Namespace.new("__stripe_event__", ".")
end
