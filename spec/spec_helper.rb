require 'stripe_event'
require 'coveralls'
require 'webmock/rspec'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__), &method(:require))

Coveralls.wear!

RSpec.configure do |config|
  config.order = :random

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    signing_secrets = StripeEvent.signing_secrets
    event_filter = StripeEvent.event_filter
    notifier = StripeEvent.backend.notifier
    StripeEvent.backend.notifier = notifier.class.new

    example.run

    StripeEvent.signing_secrets = signing_secrets
    StripeEvent.event_filter = event_filter
    StripeEvent.backend.notifier = notifier
  end
end
