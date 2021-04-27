# frozen_string_literal: true

require_relative 'boot'

require 'data_cycle_core/engine'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    # config.load_defaults 5.0

    config.time_zone = 'Vienna'
  end
end
