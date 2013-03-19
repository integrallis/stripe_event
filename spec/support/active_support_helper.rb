module ActiveSupportHelper
  def subscribers_for_type(name)
    ActiveSupport::Notifications.notifier.listeners_for(name)
  end
end
