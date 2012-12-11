require "stripe"
require "stripe_event/engine"
require "stripe_event/subscriber"
require "stripe_event/publisher"

module StripeEvent
  mattr_accessor :event_retriever
  self.event_retriever = Proc.new { |params| Stripe::Event.retrieve(params[:id]) }

  class << self
    alias_method :setup, :instance_eval
  end

  def self.publish(event)
    Publisher.new(event).instrument
  end

  def self.subscribe(*names, &block)
    Subscriber.new(*names).register(&block)
  end

  class StripeEventError < StandardError; end
  class InvalidEventTypeError < StripeEventError; end

  TYPE_LIST = [
    'account.updated',
    'account.application.deauthorized',
    'charge.succeeded',
    'charge.failed',
    'charge.refunded',
    'charge.dispute.created',
    'charge.dispute.updated',
    'charge.dispute.closed',
    'customer.created',
    'customer.updated',
    'customer.deleted',
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
    'coupon.updated',
    'coupon.deleted',
    'transfer.created',
    'transfer.updated',
    'transfer.failed',
    'ping'
  ]
end
