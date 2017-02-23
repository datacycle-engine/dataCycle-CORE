require 'rails'
require 'sass-rails'
require 'turbolinks'
require 'jquery-rails'
# authentication
require 'devise'
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
end

# authorization
require 'cancancan'
# foundation helper
require 'foundation-rails'
require 'foundation_rails_helper'
require 'devise-foundation-views'

# google material icons wrapper
require 'material_icons'
# pagination
require 'kaminari'

module DataCycleCore
  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    config.assets.precompile += ['data_cycle_core/*']
    # initializer 'any_login.assets_precompile', :group => :all do |app|
    #  app.config.assets.precompile += ['data_cycle_core/*']
    # end

    require 'pg'
    require 'activerecord-postgis-adapter'
    require 'rgeo'
    require 'mongoid'

    # use active_record as orm (!not mongoid)
    config.app_generators.orm = :active_record
    config.active_record.schema_format = :sql

    # REST-client
    require 'faraday'
    # simple logger
    require 'logging'

    # config i18n for db and UI
    require 'globalize'
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = :de
    # fallbacks for i18n and Globalize
    config.i18n.fallbacks = true
    # add specific fallbacks for Globalize
    Globalize.fallbacks = {en: [:de], de: [:en]}

    # db-viewer only in development environment
    if Rails.env == "development"

      require 'rails_db'
      if Object.const_defined?('RailsDb')
        RailsDb.setup do |config|
          config.black_list_tables = ['spatial_ref_sys', 'ar_internal_metadata']
          #config.verify_access_proc = proc { |controller| controller.current_user.admin? }
        end
      end

    end

  end
end
