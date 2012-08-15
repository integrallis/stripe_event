require "stripe"
require "stripe_event/engine"
require "stripe_event/subscriber"
require "stripe_event/types"

module StripeEvent
  class << self
    alias_method :setup, :instance_eval
  end
  
  def self.registration(&block)
    warn "[Deprecation Warning] StripeEvent.registration is deprecated. Use StripeEvent.setup."
    instance_eval(&block)
  end
  
  def self.publish(event_obj)
    ActiveSupport::Notifications.instrument(event_obj.type, :event => event_obj)
  end
  
  def self.subscribe(*names, &block)
    Subscriber.new(*names, &block).register
  end
  
  def self.subscribers(name)
    ActiveSupport::Notifications.notifier.listeners_for(name)
  end
  
  def self.clear_subscribers!
    TYPE_LIST.each do |type|
      subscribers(type).each { |s| unsubscribe(s) }
    end
  end
  
  def self.unsubscribe(subscriber)
    ActiveSupport::Notifications.notifier.unsubscribe(subscriber)
  end
end
