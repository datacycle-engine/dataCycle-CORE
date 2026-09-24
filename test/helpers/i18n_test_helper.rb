# frozen_string_literal: true

module DataCycleCore
  # Adds translations for the duration of a test and restores the EXACT prior state afterwards.
  #
  # Replaces `I18n.reload!` as the cleanup step. reload! looks as if it restored the boot state,
  # but it only does so for files in I18n.load_path: the base error texts of
  # dry-schema/dry-validation are injected into the backend programmatically at boot and live in
  # no load_path file. reload! therefore drops them PERMANENTLY for the rest of the worker
  # process — demonstrable with I18n.t('dry_validation.errors.filled?', locale: :en), which
  # resolves before reload! and no longer after it.
  #
  # The consequence is a failure far away from its cause: EVERY later API test in the same worker
  # that validates an invalid parameter dies with Dry::Schema::MissingMessageError — and which
  # test that hits depends on how files are distributed across workers, so it moves with a
  # different worker count or a newly added test.
  module I18nTestHelper
    # For tests that build their translations up and down in setup/teardown.
    def snapshot_translations!
      @i18n_translations_snapshot = I18n.backend.translations(do_init: true).deep_dup
    end

    def restore_translations!
      # replace rather than reassign: other places hold the same hash reference.
      I18n.backend.translations(do_init: true).replace(@i18n_translations_snapshot)
    end

    # Adds the translations in EVERY available locale for the duration of the block. All locales
    # rather than one at a time, because the locale is derived from the endpoint: a definition
    # stubbed in a single locale would assert something different depending on the endpoint's
    # language.
    # @param translations [Hash] as passed to I18n.backend.store_translations
    def with_stored_translations(translations)
      snapshot_translations!
      I18n.available_locales.each { |locale| I18n.backend.store_translations(locale, translations) }

      yield
    ensure
      restore_translations!
    end

    # Configures +locale+ for the duration of the block with translations that deliberately
    # miss the page under test.
    #
    # Pages whose translations exist for only some configured locales narrow their language
    # switcher (/schema, the OpenAPI viewer and its document). The dummy app translates both
    # into every locale it configures, so that situation has to be staged — a test that only
    # runs on instances which happen to ship an untranslated locale is not a regression test.
    #
    # @param translations [Hash] what the staged locale does carry, so it is a real locale
    #   rather than an empty one
    # @yieldparam locale [Symbol] the staged locale
    def with_untranslated_locale(locale = :zz, translations: { data_cycle_core: { something_else: 'x' } })
      original = I18n.available_locales
      snapshot_translations!
      I18n.available_locales = original + [locale]
      I18n.backend.store_translations(locale, translations)

      yield locale
    ensure
      I18n.available_locales = original
      restore_translations!
    end
  end
end
