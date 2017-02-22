module DataCycleCore
  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    require 'pg'
    require 'activerecord-postgis-adapter'
    require 'rgeo'
    require 'mongoid'

    require 'faraday'
    require 'logging'

    require 'globalize'
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = :de
    # fallbacks for i18n and Globalize
    config.i18n.fallbacks = true
    # add specific fallbacks for Globalize
    Globalize.fallbacks = {en: [:de], de: [:en]}

  end
end
