# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    # Central i18n lookup for the OpenAPI document builders. All builders run
    # inside DocumentBuilder's `I18n.with_locale` block, so the ambient locale is
    # already the requested one; translations live under the `open_api.*`
    # namespace (config/locales/open_api.*.yml).
    module Translations
      # Key that decides whether a locale carries open_api translations at all. It is the
      # document's own info.description, so a locale missing it produces a document whose
      # very first prose field is a translation-missing marker.
      ANCHOR_KEY = 'open_api.info.description'

      module_function

      # Look up a localized OpenAPI string.
      # @param key [String, Symbol] key relative to the `open_api.` namespace
      # @param opts [Hash] interpolation variables passed on to I18n
      def t(key, **)
        I18n.t("open_api.#{key}", **)
      end

      # The configured locales that actually have open_api translations. config/locales ships
      # open_api.de.yml and open_api.en.yml only, a host may configure more, and
      # config.i18n.fallbacks is off — so both the document and the viewer's switcher offer
      # this list rather than I18n.available_locales.
      #
      # @return [Array<Symbol>] configured locales carrying ANCHOR_KEY
      def available_locales
        I18n.available_locales.select { |locale| I18n.exists?(ANCHOR_KEY, locale) }
      end
    end
  end
end
