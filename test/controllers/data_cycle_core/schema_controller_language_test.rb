# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # /schema restricts its ?language= switcher twice over: once through the shared
  # AvailableLocaleResolver (is it a configured locale at all?) and once more
  # against the locales the /schema translations actually exist for.
  #
  # The second pass is the point. The gem ships fr.yml/it.yml without a `schema`
  # branch, so a locale can be perfectly valid for the rest of dataCycle and still
  # render /schema as a page of "translation missing" -- the shared resolver has no
  # way to know that, because it only knows I18n.available_locales. Offering such a
  # locale in the switcher is a dead end the user can walk into by clicking.
  #
  # Unit-level like OpenApiViewerControllerTest -- no HTTP/auth/DB needed.
  class SchemaControllerLanguageTest < ActiveSupport::TestCase
    include DataCycleCore::I18nTestHelper

    # Runs #set_schema_language for a raw ?language= value and hands back what the
    # view would see.
    def resolve(value, ui_locale: nil)
      controller = DataCycleCore::SchemaController.new
      controller.params = ActionController::Parameters.new(value.nil? ? {} : { language: value })
      user = ui_locale && Struct.new(:ui_locale).new(ui_locale)
      controller.define_singleton_method(:current_user) { user }
      controller.send(:set_schema_language)

      {
        language: controller.instance_variable_get(:@schema_language),
        available: controller.instance_variable_get(:@available_locales)
      }
    end

    # The key the filter tests for -- if it ever moves, every locale drops out of
    # the switcher and /schema silently renders in one language only.
    test 'the translation probe key exists for the default locale' do
      assert I18n.exists?('data_cycle_core.schema.root', I18n.default_locale)
    end

    test 'the switcher offers exactly the locales that have schema translations' do
      available = resolve(nil)[:available]

      assert_includes available, I18n.default_locale
      assert_empty available - I18n.available_locales
      available.each do |locale|
        assert I18n.exists?('data_cycle_core.schema.root', locale), "#{locale} is offered without schema translations"
      end
      (I18n.available_locales - available).each do |locale|
        assert_not I18n.exists?('data_cycle_core.schema.root', locale), "#{locale} has schema translations but is not offered"
      end
    end

    test 'an offered locale is used as requested' do
      resolve(nil)[:available].each do |locale|
        assert_equal locale, resolve(locale.to_s)[:language]
      end
    end

    # The regression: a configured-but-untranslated locale passes the shared
    # resolver and used to be handed straight to the view, which then rendered
    # "translation missing" for every label on the page.
    test 'a configured locale without schema translations is neither offered nor used' do
      with_untranslated_locale do |locale|
        resolved = resolve(locale.to_s)

        assert_not_includes resolved[:available], locale
        assert_not_equal locale, resolved[:language]
        assert_includes resolved[:available], resolved[:language]
      end
    end

    # …including when it arrives as a user's UI locale rather than in the URL: the
    # shared resolver falls back to current_user.ui_locale before the default, so
    # the same untranslated locale can enter through that door too.
    test 'an untranslated ui_locale does not win either' do
      with_untranslated_locale do |locale|
        resolved = resolve(nil, ui_locale: locale.to_s)

        assert_not_equal locale, resolved[:language]
        assert_includes resolved[:available], resolved[:language]
      end
    end

    test 'a missing, blank or bogus language always resolves to an offered locale' do
      [nil, '', 'zz', 'de-DE', '../../etc/passwd', 'en; DROP TABLE things', '123'].each do |value|
        resolved = resolve(value)

        assert_includes resolved[:available], resolved[:language], "#{value.inspect} resolved outside the offered locales"
      end
    end
  end
end
