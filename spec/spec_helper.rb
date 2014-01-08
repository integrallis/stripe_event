require 'coveralls'
Coveralls.wear!

require 'webmock/rspec'
require File.expand_path('../../lib/stripe_event', __FILE__)
Dir[File.expand_path('../spec/support/**/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|
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
