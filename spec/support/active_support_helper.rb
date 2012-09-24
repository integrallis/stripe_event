module ActiveSupportHelper
  def clear_subscribers_for_list(type_list)
    type_list.each do |type|
      subscribers_for_type(type).each { |s| unsubscribe(s) }
    end
  end
  
  def subscribers_for_type(name)
    ActiveSupport::Notifications.notifier.listeners_for(name)
  end
  
  def unsubscribe(subscriber)
    ActiveSupport::Notifications.notifier.unsubscribe(subscriber)
  end
end
