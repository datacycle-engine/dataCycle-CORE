# frozen_string_literal: true

Devise.setup do |config|
  config.router_name = :data_cycle_core
  config.parent_controller = 'DataCycleCore::ApplicationController'
  config.mailer_sender = 'webmaster@pixelpoint.at'
  config.mailer = 'DataCycleCore::UserMailer'
  require 'devise/orm/active_record'
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 11
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = URI::MailTo::EMAIL_REGEXP
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete
  config.lock_strategy = :failed_attempts
  config.maximum_attempts = 3
  config.unlock_strategy = :time
  config.unlock_in = 1.hour
  config.http_authenticatable = true
  config.secret_key = ENV['SECRET_KEY_BASE']

  if ENV['PIXELPOINT_AAD_V2_CLIENT_ID'].present?
    require 'omniauth-entra-id'
    config.omniauth :pixelpoint_aad_v2, {
      name: 'pixelpoint_aad_v2',
      controller: 'data_cycle_core/omniauth', # used for custom omniauth callbacks controller in project
      client_id: ENV['PIXELPOINT_AAD_V2_CLIENT_ID'],
      client_secret: ENV['PIXELPOINT_AAD_V2_CLIENT_SECRET'],
      tenant_id: ENV['PIXELPOINT_AAD_V2_TENANT_ID'],
      strategy_class: OmniAuth::Strategies::EntraId,
      default_role: 'system_admin',
      # DC-25: restrict OAuth provisioning/sign-in to these email domains (comma/space separated,
      # ENV-overridable). The EntraId app is single-tenant, so this stops tenant guests / B2B
      # accounts from self-provisioning a (system_admin) account via the default_role above.
      allowed_email_domains: ENV['PIXELPOINT_AAD_V2_ALLOWED_EMAIL_DOMAINS'].presence || 'pixelpoint.at,datacycle.info'
    }
  end

  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :email_password, :guest_user, :api_bearer_token, :api_token, :download_token
    manager.failure_app = DataCycleCore::CustomDeviseFailureApp
  end
end
