# frozen_string_literal: true

require_relative 'boot'

require_relative '../lib/require_rails'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.

    # config.load_defaults 5.0
    # Finished in 223.621026s, 4.9101 runs/s, 12.9013 assertions/s.
    # 1098 runs, 2885 assertions, 64 failures, 520 errors, 0 skips

    # config.load_defaults 6.0
    # Finished in 223.922188s, 4.9035 runs/s, 12.8750 assertions/s.
    # 1098 runs, 2883 assertions, 65 failures, 520 errors, 0 skips

    # config.load_defaults 6.1
    # Finished in 226.624124s, 4.8450 runs/s, 12.7215 assertions/s.
    # 1098 runs, 2883 assertions, 65 failures, 520 errors, 0 skips
    # translation gem

    # rails 7.0
    # monkey_patch: postgresql adapters: duration
    # active_record updates
    # mongoid current: 7.0.x, mongoid > 7.3 may be required for rails 7. monogid > 7.0 will break some code

    # ruby 3.0
    # keyword_argument seperation

    # ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ['--clean', '--if-exists']

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
