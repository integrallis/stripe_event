require "set"
require "stripe"
require "stripe_event/engine"

module StripeEvent
  class << self
    attr_accessor :backend, :event_retriever

    def setup(&block)
      instance_eval(&block)
    end

    def instrument(params)
      begin
        event = event_retriever.call(params)
      rescue Stripe::StripeError => e
        raise UnauthorizedError.new(e)
      end

      publish(event)
    end

    def publish(event)
      backend.publish(event[:type], event)
    end

    def subscribe(*names, &block)
      pattern = Regexp.union(names.empty? ? TYPE_LIST.to_a : names)
      backend.subscribe pattern, NotificationAdapter.new(block)
    end
  end

  class UnauthorizedError < StandardError; end

  self.backend = ActiveSupport::Notifications
  self.event_retriever = lambda { |params| Stripe::Event.retrieve(params[:id]) }

  class NotificationAdapter < Struct.new(:subscriber)
    def call(*args)
      payload = args.last
      subscriber.call(payload)
    end
  end

  TYPE_LIST = Set[
    'account.updated',
    'account.application.deauthorized',
    'balance.available',
    'charge.succeeded',
    'charge.failed',
    'charge.refunded',
    'charge.captured',
    'charge.dispute.created',
    'charge.dispute.updated',
    'charge.dispute.closed',
    'customer.created',
    'customer.updated',
    'customer.deleted',
    'customer.card.created',
    'customer.card.updated',
    'customer.card.deleted',
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted',
    'customer.subscription.trial_will_end',
    'customer.discount.created',
    'customer.discount.updated',
    'customer.discount.deleted',
    'invoice.created',
    'invoice.updated',
    'invoice.payment_succeeded',
    'invoice.payment_failed',
    'invoiceitem.created',
    'invoiceitem.updated',
    'invoiceitem.deleted',
    'plan.created',
    'plan.updated',
    'plan.deleted',
    'coupon.created',
    'coupon.deleted',
    'transfer.created',
    'transfer.updated',
    'transfer.paid',
    'transfer.failed',
    'ping'
  ].freeze
end
