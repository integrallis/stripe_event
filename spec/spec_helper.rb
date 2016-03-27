require 'coveralls'
Coveralls.wear!

require 'webmock/rspec'

require File.expand_path('../../lib/stripe_event', __FILE__)

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }
RSpec.configure do |config|
  config.order = 'random'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
