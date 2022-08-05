$LOAD_PATH.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "stripe_event/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "stripe_event"
  s.version     = StripeEvent::VERSION
  s.license     = "MIT"
  s.authors     = ["Danny Whalen"]
  s.email       = "daniel.r.whalen@gmail.com"
  s.homepage    = "https://github.com/integrallis/stripe_event"
  s.summary     = "Stripe webhook integration for Rails applications."
  s.description = "Stripe webhook integration for Rails applications."

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- Appraisals {spec,gemfiles}/*`.split("\n")

  s.add_dependency "activesupport", ">= 3.1"
  s.add_dependency "stripe", [">= 2.8", "< 8"]

  s.add_development_dependency "appraisal"
  s.add_development_dependency "coveralls"
  s.add_development_dependency "rails", [">= 3.1"]
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec-rails", "~> 3.7"
  s.add_development_dependency "webmock", "~> 1.9"
end
