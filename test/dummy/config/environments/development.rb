# frozen_string_literal: true

if defined?(BetterErrors)
  BetterErrors::Middleware.allow_ip! '10.0.0.0/8'
  BetterErrors::Middleware.allow_ip! '172.16.0.0/12'
  BetterErrors::Middleware.allow_ip! '172.18.0.0/12'
  BetterErrors::Middleware.allow_ip! '192.168.0.0/16'
end

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = true

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    if Rails.application.secrets.dig(:redis_server).present?
      config.cache_store = :redis_cache_store, {
        url: "redis://#{Rails.application.secrets.redis_server}:#{Rails.application.secrets.redis_port}/#{Rails.application.secrets.redis_cache_database}",
        namespace: Rails.application.secrets.redis_cache_namespace
      }
    else
      config.cache_store = :memory_store
    end

    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local
  config.active_storage.resolve_model_to_route = :rails_storage_proxy

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  # config.assets.debug = true

  # Suppress logger output for asset requests.
  # config.assets.quiet = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  config.web_console.whiny_requests = false if config.respond_to?(:web_console)

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_options = { from: "noreply@#{ENV.fetch('APP_HOST', 'localhost')}" }
  config.action_mailer.smtp_settings = { address: ENV.fetch('MAILHOG_HOST', 'localhost'), port: 1025 }
  config.action_mailer.default_url_options = { host: ENV.fetch('APP_HOST', 'localhost:3003'), protocol: ENV.fetch('APP_PROTOCOL', 'http') } # required for action_mailer (Missing host to link to! Please provide the :host parameter, set default_url_options[:host])

  config.asset_host = config.action_mailer.default_url_options&.slice(:protocol, :host)&.values&.join('://')

  # config.hosts.clear

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Bullet configuration:
  # only activate if required for local testing
  config.after_initialize do
    Prosopite.raise = false
    Prosopite.rails_logger = true
    Prosopite.prosopite_logger = true
    Prosopite.stderr_logger = true
    Prosopite.enabled = true
  end
  config.action_cable.url = '/cable'
  config.action_cable.allowed_request_origins = [config.asset_host]
end
