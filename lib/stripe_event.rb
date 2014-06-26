require "active_support/notifications"
require "stripe"
require "stripe_event/engine" if defined?(Rails)

module StripeEvent
  class << self
    attr_accessor :adapter, :backend, :event_retriever, :namespace, :ignore_test_webhooks

    def configure(&block)
      raise ArgumentError, "must provide a block" unless block_given?
      block.arity.zero? ? instance_eval(&block) : yield(self)
    end
    alias :setup :configure

    def instrument(params)
      return if test_webhook?(params) && ignore_test_webhooks
      begin
        event = event_retriever.call(params)
      rescue Stripe::AuthenticationError => e
        if params[:type] == "account.application.deauthorized"
          event = Stripe::Event.construct_from(params.deep_symbolize_keys)
        else
          raise UnauthorizedError.new(e)
        end
      rescue Stripe::StripeError => e
        raise UnauthorizedError.new(e)
      end

      backend.instrument namespace.call(event[:type]), event
    end

    def test_webhook?(webhook_params)
      !webhook_params[:livemode]
    end

    def subscribe(name, callable = Proc.new)
      backend.subscribe namespace.to_regexp(name), adapter.call(callable)
    end

    def all(callable = Proc.new)
      subscribe nil, callable
    end
  end

  class Namespace < Struct.new(:value, :delimiter)
    def call(name = nil)
      "#{value}#{delimiter}#{name}"
    end

    def to_regexp(name = nil)
      %r{^#{Regexp.escape call(name)}}
    end
  end

  class NotificationAdapter < Struct.new(:subscriber)
    def self.call(callable)
      new(callable)
    end

    def call(*args)
      payload = args.last
      subscriber.call(payload)
    end
  end

  class Error < StandardError; end
  class UnauthorizedError < Error; end

  self.adapter = NotificationAdapter
  self.backend = ActiveSupport::Notifications
  self.event_retriever = lambda { |params| Stripe::Event.retrieve(params[:id]) }
  self.namespace = Namespace.new("stripe_event", ".")
  self.ignore_test_webhooks = false
end
