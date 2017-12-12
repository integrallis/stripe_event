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
    @signing_secrets = StripeEvent.signing_secrets
    @event_filter = StripeEvent.event_filter
    @notifier = StripeEvent.backend.notifier
    StripeEvent.backend.notifier = @notifier.class.new
  end

  config.after do
    StripeEvent.signing_secrets = @signing_secrets
    StripeEvent.event_filter = @event_filter
    StripeEvent.backend.notifier = @notifier
  end
end
