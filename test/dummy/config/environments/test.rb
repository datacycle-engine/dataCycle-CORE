# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

# Register the :pixelpoint_aad_v2 omniauth provider in the test suite by supplying dummy
# AAD credentials when none are set (e.g. CI, fresh checkouts), so omniauth-dependent code
# stays exercised consistently (User.from_omniauth, the provider's `*_uid` store accessor).
# Must run before the engine's config/initializers/devise.rb, which registers the provider
# from these ENV vars — this environment file loads before engine initializers. EntraId
# resolves endpoints lazily, so placeholder credentials never trigger network calls.
ENV['PIXELPOINT_AAD_V2_CLIENT_ID'] ||= 'test-client-id'
ENV['PIXELPOINT_AAD_V2_CLIENT_SECRET'] ||= 'test-client-secret'
ENV['PIXELPOINT_AAD_V2_TENANT_ID'] ||= 'test-tenant-id'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = false

  # config.active_job.queue_adapter = :test # problems with backtrace in test failures
  config.active_job.queue_adapter = :delayed_job
  # config.action_view.cache_template_loading = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  # @todo validate after fixed tests
  config.eager_load = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and enable caching for rate-limiting / throttling tests.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test
  config.active_storage.resolve_model_to_route = :rails_storage_proxy

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_options = { from: 'test@datacyle.info' }

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  config.action_mailer.default_url_options = { host: 'localhost:3000', protocol: 'http' } # required for action_mailer (Missing host to link to! Please provide the :host parameter, set default_url_options[:host])

  config.asset_host = config.action_mailer.default_url_options&.slice(:protocol, :host)&.values&.join('://')
  config.action_cable.url = '/cable'
  config.action_cable.allowed_request_origins = [config.action_mailer.default_url_options&.slice(:protocol, :host)&.values&.join('://')]
end
