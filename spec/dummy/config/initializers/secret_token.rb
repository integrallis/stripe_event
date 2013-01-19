# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

key = 'e13aca438075c637003a11031f93861a73aea50c8520fd45af70c28f55348930da4274d3965462bbcf81b6e08f4eeb03cdda627a59379cd7ab15a2cbe6648ce2'

# Renamed in Rails 4 - we'll avoid deprecation warning
# by checking if config responds to 'secret_key_base='
if Dummy::Application.config.respond_to? :secret_key_base=
  Dummy::Application.config.secret_key_base = key
else
  Dummy::Application.config.secret_token = key
end
