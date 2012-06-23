require "stripe"
require "stripe_event/engine"
require "stripe_event/types"

module StripeEvent
  InvalidEventType = Class.new(StandardError)
  
  def self.configure
    yield self
    self
  end
  
  def self.subscribe(name, &block)
    raise InvalidEventType if !TYPES.include?(name)
    ActiveSupport::Notifications.subscribe(name, &block)
  end
  
  def self.subscribers(name)
    ActiveSupport::Notifications.notifier.listeners_for(name)
  end
  
  def self.clear_subscribers!
    TYPES.each do |type|
      subscribers(type).each { |s| unsubscribe(s) }
    end
  end
  
  def self.unsubscribe(subscriber)
    ActiveSupport::Notifications.notifier.unsubscribe(subscriber)
  end
end
