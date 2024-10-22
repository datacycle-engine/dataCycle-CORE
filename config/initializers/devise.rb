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
  config.lock_strategy = :none
  config.unlock_strategy = :none
  config.http_authenticatable = true

  if ENV['PIXELPOINT_AAD_V2_CLIENT_ID'].present?
    require 'omniauth-entra-id'
    config.omniauth :pixelpoint_aad_v2, {
      name: 'pixelpoint_aad_v2',
      client_id: ENV['PIXELPOINT_AAD_V2_CLIENT_ID'],
      client_secret: ENV['PIXELPOINT_AAD_V2_CLIENT_SECRET'],
      tenant_id: ENV['PIXELPOINT_AAD_V2_TENANT_ID'],
      strategy_class: OmniAuth::Strategies::EntraId,
      default_role: 'super_admin'
    }
  end

  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :email_password, :guest_user, :api_bearer_token, :api_token, :download_token
    manager.failure_app = DataCycleCore::CustomDeviseFailureApp
  end
end
