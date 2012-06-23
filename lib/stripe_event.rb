require "stripe"
require "stripe_event/engine"

module StripeEvent
  
  def self.subscribe(name, &block)
    ActiveSupport::Notifications.subscribe(name, &block)
  end
  
  def self.subscribers(name)
    ActiveSupport::Notifications.notifier.listeners_for(name)
  end
end
