require 'active_support/notifications'
require 'stripe'
require 'stripe_event/engine' if defined?(Rails)
require 'stripe_event/configuration'
require 'stripe_event/exceptions'
require 'stripe_event/namespace'
require 'stripe_event/notification_adapter'
require 'stripe_event/version'

module StripeEvent
  class << self
    def configure(&block)
      Configuration.instance.configure(&block)
    end
    alias setup configure

    def instrument(event)
      event = event_filter.call(event)
      return unless event
      backend.instrument(namespace.call(event.type), event)
    end

    def subscribe(name, callable = Proc.new)
      backend.subscribe(namespace.to_regexp(name), adapter.call(callable))
    end

    def all(callable = Proc.new)
      subscribe(nil, callable)
    end

    def listening?(name)
      namespaced_name = namespace.call(name)
      backend.notifier.listening?(namespaced_name)
    end

    def method_missing(method_name, *arguments, &block)
      if configuration.respond_to?(method_name.to_sym)
        configuration.send(method_name.to_sym, *arguments, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      configuration.respond_to?(method_name.to_sym) || super
    end

    private

    def configuration
      Configuration.instance
    end
  end
end
