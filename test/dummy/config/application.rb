# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require 'data_cycle_core'

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.0

    config.assets.paths << Rails.root.join('lib', 'assets', 'stylesheets')
    config.assets.paths << Rails.root.join('lib', 'assets', 'javascripts')
    config.assets.paths << Rails.root.join('lib', 'assets', 'fonts')

    config.assets.paths << Rails.root.join('..', '..', 'lib', 'assets', 'stylesheets')
    config.assets.paths << Rails.root.join('..', '..', 'lib', 'assets', 'javascripts')
    config.assets.paths << Rails.root.join('..', '..', 'lib', 'assets', 'fonts')

    config.time_zone = 'Vienna'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
