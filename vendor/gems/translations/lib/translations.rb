# frozen_string_literal: true

require 'i18n'
require 'request_store'
require 'translations/version'

module Translations
  require 'translations/attributes'
  require 'translations/backend'
  require 'translations/backends'
  require 'translations/configuration'
  require 'translations/loaded'
  require 'translations/plugin'
  require 'translations/plugins'
  require 'translations/translates'

  require 'rails'
  require 'active_record'
  # require 'translations/active_model'
  require 'translations/active_record'

  class << self
    def extended(model_class)
      return if model_class.respond_to? :translation_accessor

      model_class.extend Translations::Translates
      model_class.extend ClassMethods

      if (translates = Translations.config.accessor_method)
        model_class.singleton_class.send(:alias_method, translates, :translation_accessor)
      end

      model_class.include(Translations::ActiveRecord)
    end

    def included(model_class)
      model_class.extend self
    end

    def storage
      RequestStore.store
    end

    def config
      @config ||= Translations::Configuration.new
    end

    def get_class_from_key(parent_class, key)
      klass_name = key.to_s.gsub(/(^|_)(.)/) { |x| x[-1..-1].upcase }
      parent_class.const_get(klass_name)
    end

    [:accessor_method, :query_method, :default_backend, :default_options, :plugins].each do |method_name|
      define_method method_name do
        config.public_send(method_name)
      end
    end

    def configure
      yield config
    end

    def normalize_locale(locale = I18n.locale)
      locale.to_s.downcase.tr('-', '_').to_s
    end
    alias normalized_locale normalize_locale

    def enforce_available_locales!(locale)
      raise Translations::InvalidLocale, locale unless available_locales.include?(locale.to_sym)
    end

    def available_locales
      I18n.available_locales
    end
  end

  module ClassMethods
    def translation_attributes
      []
    end
  end

  class InvalidLocale < I18n::InvalidLocale; end
  class NotImplementedError < StandardError; end
end
