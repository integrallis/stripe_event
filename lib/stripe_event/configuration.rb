require 'singleton'

module StripeEvent
  class Configuration
    include Singleton

    attr_accessor :adapter, :backend, :namespace, :event_filter
    attr_reader :signing_secrets

    def initialize
      @adapter = NotificationAdapter
      @backend = ActiveSupport::Notifications
      @namespace = Namespace.new('stripe_event', '.')
      @event_filter = ->(event) { event }
    end

    def configure(&block)
      raise ArgumentError, 'must provide a block' unless block_given?
      block.arity.zero? ? instance_eval(&block) : yield(self)
    end

    def signing_secret=(value)
      @signing_secrets = Array(value)
    end
    alias signing_secrets= signing_secret=

    def signing_secret
      @signing_secrets && @signing_secrets.first
    end
  end
end
