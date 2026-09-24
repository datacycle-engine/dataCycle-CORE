# frozen_string_literal: true

module DataCycleCore
  # Shared "requested → configured? → fallback → default" locale resolution for
  # endpoints with a ?language= switcher (/schema, the OpenAPI viewer and the
  # /api/config/openapi document). Keeps the allowlist logic in one place.
  module AvailableLocaleResolver
    extend ActiveSupport::Concern

    private

    # Restricts +requested+ to one of +available+. Falls back to +fallback+ (e.g. the
    # user's UI locale) when that is available, then to the I18n default, then to the
    # first available locale. Coerces to String first so array params (?language[]=de)
    # fall back to a valid locale instead of raising.
    #
    # +available+ narrows past I18n.available_locales for pages translated into only some
    # configured locales; config.i18n.fallbacks is off, so serving one of the others renders
    # "Translation missing: …" instead of a fallback. The last step covers an untranslated
    # I18n default, so a narrowed list can never resolve outside itself.
    #
    # @param available [Array<Symbol>] the locales the caller is willing to serve
    # @return [Symbol] a locale from +available+, unless it is empty
    def resolve_available_locale(requested, fallback: current_user&.ui_locale, available: I18n.available_locales)
      requested = requested.to_s.presence&.to_sym
      return requested if available.include?(requested)

      fallback = fallback.to_s.presence&.to_sym
      return fallback if available.include?(fallback)
      return I18n.default_locale if available.include?(I18n.default_locale)

      available.first || I18n.default_locale
    end
  end
end
