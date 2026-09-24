# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Verifies that OpenApiViewerController restricts the `language` query parameter to the
  # instance's configured locales (mirroring Api::Config::OpenapiController), falling back
  # to the user's UI locale and then the default locale instead of passing arbitrary values
  # through to I18n. Unit-level, like Api::Config::OpenapiTest — no HTTP/auth needed.
  class OpenApiViewerControllerTest < ActiveSupport::TestCase
    include DataCycleCore::I18nTestHelper

    # Resolves the controller's `resolve_available_locale` (from AvailableLocaleResolver, how
    # #show derives @spec_language) for a raw `language` param value and optional signed-in
    # user UI locale. Passing +available+ adds the narrowing #show applies.
    def resolved_spec_language(value, ui_locale: nil, available: nil)
      controller = DataCycleCore::OpenApiViewerController.new
      controller.params = ActionController::Parameters.new(value.nil? ? {} : { language: value })
      user = ui_locale && Struct.new(:ui_locale).new(ui_locale)
      controller.define_singleton_method(:current_user) { user }
      narrowing = available.nil? ? {} : { available: }

      controller.send(:resolve_available_locale, controller.params[:language], **narrowing)
    end

    test 'supported languages are used as requested' do
      I18n.available_locales.each do |locale|
        assert_equal locale, resolved_spec_language(locale.to_s)
      end
    end

    test 'a missing or blank language falls back to the default locale' do
      assert_equal I18n.default_locale, resolved_spec_language(nil)
      assert_equal I18n.default_locale, resolved_spec_language('')
    end

    test 'unsupported and malicious language values are restricted to the default locale' do
      ['zz', 'de-DE', 'EN', '../../etc/passwd', 'en; DROP TABLE things', '123'].each do |value|
        next if I18n.available_locales.include?(value.to_sym)

        assert_equal I18n.default_locale, resolved_spec_language(value), "#{value.inspect} was not restricted"
      end
    end

    test 'an invalid language falls back to the signed-in users ui_locale when configured' do
      fallback = I18n.available_locales.find { |l| l != I18n.default_locale } || I18n.default_locale

      assert_equal fallback, resolved_spec_language('zz', ui_locale: fallback.to_s)
    end

    test 'an invalid ui_locale is ignored in favour of the default locale' do
      assert_equal I18n.default_locale, resolved_spec_language('zz', ui_locale: 'zz')
    end

    test 'the resolved locale is always one of the configured locales' do
      ['de', 'en', 'zz', 'garbage', '', nil].each do |value|
        assert_includes I18n.available_locales, resolved_spec_language(value), "#{value.inspect} resolved outside available_locales"
      end
    end

    # ---- the switcher only offers translated locales (see OpenApi::Translations) ----

    # If the probe key ever moves, every locale drops out and the viewer silently offers
    # one language only.
    test 'the translation probe key exists for the default locale' do
      assert I18n.exists?(DataCycleCore::OpenApi::Translations::ANCHOR_KEY, I18n.default_locale)
    end

    test 'exactly the locales with open_api translations are offered' do
      available = DataCycleCore::OpenApi::Translations.available_locales

      assert_includes available, I18n.default_locale
      I18n.available_locales.each do |locale|
        assert_equal(
          I18n.exists?(DataCycleCore::OpenApi::Translations::ANCHOR_KEY, locale),
          available.include?(locale),
          "#{locale} is offered iff it has open_api translations"
        )
      end
    end

    test 'a configured locale without open_api translations is neither offered nor used' do
      with_untranslated_locale do |locale|
        available = DataCycleCore::OpenApi::Translations.available_locales

        assert_not_includes available, locale
        assert_includes available, resolved_spec_language(locale.to_s, available:)
      end
    end

    test 'an untranslated ui_locale does not win either' do
      with_untranslated_locale do |locale|
        available = DataCycleCore::OpenApi::Translations.available_locales

        assert_includes available, resolved_spec_language(nil, ui_locale: locale.to_s, available:)
      end
    end

    # Same narrowing on the document itself, so a hand-written ?language=fr cannot produce
    # a body full of translation-missing markers either.
    test 'the openapi document restricts language to a translated locale' do
      with_untranslated_locale do |locale|
        controller = DataCycleCore::Api::Config::OpenapiController.new
        controller.define_singleton_method(:permitted_params) { { language: locale.to_s } }

        assert_includes DataCycleCore::OpenApi::Translations.available_locales, controller.send(:locale)
      end
    end
  end
end
