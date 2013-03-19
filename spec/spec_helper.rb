# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'webmock/rspec'

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(ENGINE_RAILS_ROOT, "spec/support/**/*.rb")].each {|f| require f }

RSpec.configure do |config|
  config.include(FixtureHelper)
  config.include(ActiveSupportHelper)

  config.order = 'random'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    @_event_retriever = StripeEvent.event_retriever
    @_notifier = StripeEvent.backend.notifier
    StripeEvent.backend.notifier = @_notifier.class.new
  end

  config.after do
    StripeEvent.event_retriever = @_event_retriever
    StripeEvent.backend.notifier = @_notifier
  end
end
