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
