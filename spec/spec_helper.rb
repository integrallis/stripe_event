ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'

support_dir = File.join(File.dirname(__FILE__), '../spec/support/**/*.rb')
Dir[support_dir].each { |f| require f }

RSpec.configure do |config|
  config.include FixtureHelper
  config.include ActiveSupportHelper

  config.order = 'random'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    @event_retriever = StripeEvent.event_retriever
    @notifier = StripeEvent.backend.notifier
    StripeEvent.backend.notifier = @notifier.class.new
  end

  config.after do
    StripeEvent.event_retriever = @event_retriever
    StripeEvent.backend.notifier = @notifier
  end
end
