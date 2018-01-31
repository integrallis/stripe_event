if Gem::Version.new(Rails::VERSION::STRING) > Gem::Version.new("5.1.999")
  # New default in Rails 5.2
  Rails.application.config.action_controller.default_protect_from_forgery = true
end
