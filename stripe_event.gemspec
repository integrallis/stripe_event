$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "stripe_event/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "stripe_event"
  s.version     = StripeEvent::VERSION
  s.authors     = ["Danny Whalen"]
  s.email       = ["dwhalen@integrallis.com"]
  s.homepage    = "https://github.com/integrallis/stripe_event"
  s.summary     = "Stripe webhook integration for Rails applications."
  s.description = "Stripe webhook integration for Rails applications."

  s.files = Dir["{app,config,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 3.1"
  s.add_dependency "stripe", "~> 1.6"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails", "~> 2.10"
  s.add_development_dependency "webmock"
end
