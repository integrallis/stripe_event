### [Unreleased] - TBD

### 2.6.0 (Aug 8, 2022)

- Introduce StripeEvent::ProcessError and possible HTTP 422 responses (#155, #132)

### 2.5.0 (Aug 5, 2022)

- Add Stripe 7 support (#154)

### 2.4.0 (May 12, 2022)

- Add Stripe 6 support (#151)
- Add Rails 7 support (#151)
- Add Ruby 3.1 support (#152)
- Improved build matrix

### 2.3.2 (February 21, 2022)

- Fix signature validation error if the first signing secret is nil (#146)
- Update README (#143)
- Setup github actions for CI (#147)

### 2.3.1 (May 12, 2020)

- Fix deprecation warning in Ruby 2.7 (#130)
- Fixes tests for Stripe 5.19.0 (#133)

### 2.3.0 (August 23, 2019)

- Add support for Stripe v5.x (#119)
- Add support for Rails v6.x to the build matrix (#119)

### 2.2.0 (December 6, 2018)

- Add support for Stripe v4.x (#119)
- Documentation Updates and Fixes (#113 and #117)

### 2.1.1 (January 31, 2018)

- Adds better support for Rails 5.2 (#105, #106, #107)
- `StripeEvent::WebhookController` now calls `skip_before_action :verify_authenticity_token` if `Rails.application.config.action_controller.default_protect_from_forgery` is set (as it is by default in Rails 5.2)

### 2.1.0 (yanked)

### 2.0.0 (December 14, 2017)

**Backwards incompatible release. [Signed webhooks are now required.](https://stripe.com/docs/webhooks#signatures).**

- **Requires `StripeEvent.signing_secret` configuration** (#95, #97)
- Adds support for multiple signing secrets using `StripeEvent.signing_secrets` (#98, #99)
- Removes `StripeEvent.authentication_secret` and associated basic auth support (#97)
- Adds `StripeEvent.event_filter` (replaces use-cases for the now removed `event_retriever` config) (#97)

### 1.9.1 (December 5, 2017)

This release is in preparation for some backward incompatible changes due to
arrive in v2.0.0.  It is highly recommended that everyone secure their webhook
endpoints by using `StripeEvent.signing_secret`. See the README and [Stripe's
documentation](https://stripe.com/docs/webhooks#signatures) for more
information.

  * Deprecate `StripeEvent.authentication_secret` (#96)
  * Deprecate unverified use of Stripe's webhooks (#96)

### 1.9.0 (November 30, 2017)

  * Support for Rails 5.1 (#94, Thanks @krasnoukhov and @simplepractice!)

### 1.8.0 (August 29, 2017)

  * Support for [Stripe's Webhook Signature Verification](https://stripe.com/docs/webhooks#signatures) (#83, #90, Thanks @mikeycgto!)
  * Secure compare during basic authentication check (#91, Thanks @mikeycgto!)

### 1.7.0 (July 5, 2017)

  * Support stripe v3 gem as a dependency (#87)

### 1.6.0 (February 27, 2017)

  * Support stripe v2 gem as a dependency (#82, b3cee03)

### 1.5.1 (September 20, 2016)

  * Better Rails 5 support. Prefer `before_action` over `before_filter`. (#69, Thanks @mcolyer)

### 1.5.0 (February 25, 2015)
  * Added [replay attack protection](https://github.com/integrallis/stripe_event#securing-your-webhook-endpoint) on webhooks. See  `StripeEvent.authentication_secret`. Thanks @brentdax for both the initial discussion and the implementation! #53, #55
  * Dropped official support for Rails 3.1 and Rails 4.0

### 1.4.0 (November 1, 2014)
  * Add `StripeEvent.listening?` method to easily determine if an event type has any registered handlers. Thank you to [Vladimir Andrijevik](https://github.com/vandrijevik) for the [idea and implementation](https://github.com/integrallis/stripe_event/pull/42).

### 1.3.0 (July 22, 2014)
  * Allow for ignoring particular events. Thank you to [anark](https://github.com/anark) for suggesting the change, and [Ryan McGeary](https://github.com/rmm5t) and [Pete Keen](https://github.com/peterkeen) for working on the implementation.

### 1.2.0 (June 17, 2014)
  * Gracefully authenticate `account.application.deauthorized` events. Thank you to [Ryan McGeary](https://github.com/rmm5t) for the pull request and for taking the time to test the change in a live environment.

### 1.1.0 (January 8, 2014)
  * Deprecate `StripeEvent.setup` in favor of `StripeEvent.configure`. Remove `setup` at next major release.
  * `StripeEvent.configure` yields the module to the block for configuration.
  * `StripeEvent.configure` will raise `ArgumentError` unless a block is given.
  * Track test coverage

### 1.0.0 (December 19, 2013)
  * Internally namespace dispatched events to avoid maintaining a list of all possible event types.
  * Subscribe to all event types with `StripeEvent.all` instead of `StripeEvent.subscribe`.
  * Remove ability to subscribe to many event types with once call to `StripeEvent.subscribe`.
  * Subscribers can be an object that responds to #call.
  * Allow subscriber-generated `Stripe::StripeError`'s to bubble up. Thank you to [adamonduty](https://github.com/adamonduty) for the [patch](https://github.com/integrallis/stripe_event/pull/26).
  * Only depend on `stripe` and `activesupport` gems.
  * Add `rails` as a development dependency.
  * Only `require 'stripe_event/engine'` if `Rails` constant exists to allow StripeEvent to be used outside of a Rails application.

### 0.6.1 (August 19, 2013)
  * Update event type list
  * Update test gemfiles

### 0.6.0 (March 18, 2013)
  * Rails 4 compatibility. Thank you to Ben Ubois for reporting the [issue](https://github.com/integrallis/stripe_event/issues/13) and to Matt Goldman for the [pull request](https://github.com/integrallis/stripe_event/pull/14).
  * Run specs against different Rails versions
  * Refactor internal usage of AS::Notifications
  * Remove jruby-openssl as platform conditional dependency

### 0.5.0 (December 16, 2012)
  * Remove `Gemfile.lock` from version control
  * Internal event type list is now a set
  * Update event type list
  * Various internal refactorings
  * More readable tests

### 0.4.0 (September 24, 2012)
  * Add configuration for custom event retrieval. Thanks to Dan Hodos for the [pull request](https://github.com/integrallis/stripe_event/pull/6).
  * Move module methods only used in tests into a test helper.
  * Various internal refactorings and additional tests.
  * Error classes will inherit from a base error class now.

### 0.3.1 (August 14, 2012)
  * Fix controller inheritance issue. Thanks to Christopher Baran for [reporting the bug](https://github.com/integrallis/stripe_event/issues/1), and to Robert Bousquet for [fixing it](https://github.com/integrallis/stripe_event/pull/3).
  * Deprecate registration method. Use 'setup' instead.

### 0.3.0 (July 16, 2012)
  * Add registration method for conveniently adding many subscribers
  * Depend on jruby-openssl when running on jruby
  * Remove unneeded rake dependency
  * Remove configure method

### 0.2.0 (July 12, 2012)
  * Register a subscriber to one/many/all events
  * Remove sqlite3 development dependency
  * Setup travis-ci for repo
  * Hard code a placeholder api key in dummy app. Fixes failing tests when env var not defined.

### 0.1.1 (July 4, 2012)
  * Improve README
  * Specify development dependency versions
  * Fix controller test which was passing incorrectly

### 0.1.0 (June 24, 2012)
  * Initial release
