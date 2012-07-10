require "stripe"
require "stripe_event/engine"
require "stripe_event/types"

module StripeEvent
  
  def self.configure
    yield self
    self
  end
  
  def self.publish(event_obj)
    ActiveSupport::Notifications.instrument(event_obj.type, :event => event_obj)
  end
  
  def self.subscriber(*names, &block)
    names.each do |name|
      raise InvalidEventType.new(name) if !TYPES.include?(name)
    end
    ActiveSupport::Notifications.subscribe(Regexp.union(names), proxy(&block))
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
  
  def self.proxy(&block)
    lambda do |name, started, finished, id, payload|
      block.call(payload[:event])
    end
  end
end
