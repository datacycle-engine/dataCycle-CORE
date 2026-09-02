# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

# Always register the pixelpoint_aad_v2 OmniAuth provider in the test env. config/initializers/
# devise.rb only configures it when PIXELPOINT_AAD_V2_CLIENT_ID is present, and User generates its
# <provider>_uid store accessors from Devise.omniauth_configs at load time — so without credentials
# (e.g. on CI, where they are not set) the accessor is missing and from_omniauth / DC-25 allowlist
# tests error. Supply dummies here unless real values are already set (e.g. locally via docker).
ENV['PIXELPOINT_AAD_V2_CLIENT_ID'] = ENV['PIXELPOINT_AAD_V2_CLIENT_ID'].presence || 'test-dummy-client-id'
ENV['PIXELPOINT_AAD_V2_CLIENT_SECRET'] = ENV['PIXELPOINT_AAD_V2_CLIENT_SECRET'].presence || 'test-dummy-client-secret'
ENV['PIXELPOINT_AAD_V2_TENANT_ID'] = ENV['PIXELPOINT_AAD_V2_TENANT_ID'].presence || 'test-dummy-tenant-id'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = false

  config.active_job.queue_adapter = :test # problems with backtrace in test failures
  # config.action_view.cache_template_loading = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  # @todo validate after fixed tests
  config.eager_load = true

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

  config.active_job.logger = Logger.new(nil)
  config.action_cable.logger = Logger.new(nil)

  config.action_mailer.default_url_options = { host: 'localhost:3000', protocol: 'http' } # required for action_mailer (Missing host to link to! Please provide the :host parameter, set default_url_options[:host])

  config.asset_host = config.action_mailer.default_url_options&.slice(:protocol, :host)&.values&.join('://')
  config.action_cable.url = '/cable'
  config.action_cable.allowed_request_origins = [config.asset_host]
end
