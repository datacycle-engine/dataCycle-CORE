Devise.setup do |config|
  config.router_name = :data_cycle_core #"DataCycleCore::User"
  config.parent_controller = 'DataCycleCore::ApplicationController'
  config.mailer_sender = 'webmaster@pixelpoint.at'
  require 'devise/orm/active_record'
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 11
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :guest_user
  end
end
