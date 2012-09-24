require "stripe"
require "stripe_event/engine"
require "stripe_event/subscriber"
require "stripe_event/types"

module StripeEvent
  mattr_accessor :event_retriever
  self.event_retriever = Proc.new { |params| Stripe::Event.retrieve(params[:id]) }

  class << self
    alias_method :setup, :instance_eval
  end
  
  def self.publish(event)
    ActiveSupport::Notifications.instrument(event[:type], :event => event)
  end
  
  def self.subscribe(*names, &block)
    Subscriber.new(*names).register(&block)
  end
end
