# frozen_string_literal: true

require 'test_helper'
require 'yaml'

module DataCycleCore
  module OpenApi
    # Unit tests for the central i18n lookup used by the OpenAPI builders and a
    # guard suite that keeps the code (t('…') calls) and the locale files
    # (config/locales/open_api.*.yml) in sync across every available locale.
    class TranslationsTest < ActiveSupport::TestCase
      # Locales the OpenAPI document ships translations for. Kept explicit so a
      # newly added but only half-translated locale is caught here instead of
      # surfacing as "translation missing" in a generated document.
      OPEN_API_LOCALES = [:de, :en].freeze

      OPEN_API_DIR = DataCycleCore::Engine.root.join('app', 'models', 'data_cycle_core', 'open_api')

      # Every t('…') / Translations.t('…') string-literal key referenced in the
      # builders. Matches ` t(` and `.t(` but not `except(`, `select(`, … via the
      # negative look-behind, and only picks up quoted literal keys.
      KEY_REGEXP = /(?<![A-Za-z_])t\((["'])([a-z0-9_.]+)\1/

      # Helpers that forward a literal key straight to t(…) (e.g.
      # type_names_property('schemas.type_hierarchy')). Keys passed only through
      # these wrappers are just as "used" as a direct t('…') call.
      WRAPPER_KEY_REGEXP = /(?<![A-Za-z_])type_names_property\((["'])([a-z0-9_.]+)\1/

      def used_keys
        Dir.glob(OPEN_API_DIR.join('**', '*.rb')).flat_map { |file|
          content = File.read(file)
          content.scan(KEY_REGEXP).map { |_quote, key| key } +
            content.scan(WRAPPER_KEY_REGEXP).map { |_quote, key| key }
        }.uniq.sort
      end

      # Flattens a nested translation hash to dotted keys, e.g. { a: { b: 'x' } }
      # => { 'a.b' => 'x' }.
      def flatten_translations(hash, prefix = nil)
        hash.each_with_object({}) do |(key, value), acc|
          full = [prefix, key].compact.join('.')
          if value.is_a?(Hash)
            acc.merge!(flatten_translations(value, full))
          else
            acc[full] = value
          end
        end
      end

      def locale_file_translations(locale)
        path = DataCycleCore::Engine.root.join('config', 'locales', "open_api.#{locale}.yml")
        data = YAML.safe_load_file(path)
        flatten_translations(data.dig(locale.to_s, 'open_api'))
      end

      test 't resolves a key under the open_api namespace for the ambient locale' do
        I18n.with_locale(:en) do
          assert_equal 'The requested resource does not exist.', Translations.t('responses.not_found')
        end

        I18n.with_locale(:de) do
          assert_equal 'Die angeforderte Ressource existiert nicht.', Translations.t('responses.not_found')
        end
      end

      test 't honours an explicit locale option over the ambient locale' do
        I18n.with_locale(:en) do
          assert_equal 'Die angeforderte Ressource existiert nicht.', Translations.t('responses.not_found', locale: :de)
        end
      end

      test 't interpolates variables' do
        result = I18n.with_locale(:en) { Translations.t('schemas.entity_type', types: 'Foo, Bar') }

        assert_equal 'schema.org type hierarchy of this entity: Foo, Bar.', result

        section = I18n.with_locale(:en) { Translations.t('parameters.section_flag', key: 'meta', extra: ' X') }

        assert_equal "Toggles the `meta` section of the response envelope.\n\n`0` = omit, `1` = include. X\n", section
      end

      test 't returns a translation missing message for an unknown key' do
        result = I18n.with_locale(:en) { Translations.t('does.not.exist') }

        assert_match(/translation missing/i, result)
      end

      # --- guard suite: code <-> locale files ------------------------------

      test 'every key used in the builders is defined in every OpenAPI locale' do
        keys = used_keys

        assert_operator keys.size, :>, 100, 'expected the builders to reference many localized keys'

        OPEN_API_LOCALES.each do |locale|
          defined_keys = locale_file_translations(locale).keys
          missing = keys - defined_keys

          assert_empty missing, "open_api.#{locale}.yml is missing keys: #{missing.join(', ')}"
        end
      end

      test 'all OpenAPI locales define the exact same set of keys' do
        reference_locale = OPEN_API_LOCALES.first
        reference = locale_file_translations(reference_locale).keys.sort

        OPEN_API_LOCALES.drop(1).each do |locale|
          other = locale_file_translations(locale).keys.sort

          assert_equal reference, other,
                       "open_api.#{locale}.yml key set differs from open_api.#{reference_locale}.yml " \
                       "(only in #{reference_locale}: #{(reference - other).join(', ')}; " \
                       "only in #{locale}: #{(other - reference).join(', ')})"
        end
      end

      test 'no locale key is defined without being used by a builder' do
        keys = used_keys
        unused = locale_file_translations(OPEN_API_LOCALES.first).keys - keys

        assert_empty unused, "unused OpenAPI translation keys (remove or wire up): #{unused.join(', ')}"
      end

      test 'interpolation placeholders are identical across all OpenAPI locales' do
        placeholders_for = lambda do |translations|
          translations.transform_values { |value| value.to_s.scan(/%\{(\w+)\}/).flatten.sort }
            .reject { |_key, vars| vars.empty? }
        end

        reference_locale = OPEN_API_LOCALES.first
        reference = placeholders_for.call(locale_file_translations(reference_locale))

        OPEN_API_LOCALES.drop(1).each do |locale|
          other = placeholders_for.call(locale_file_translations(locale))

          assert_equal reference, other,
                       "interpolation placeholders differ between open_api.#{reference_locale}.yml and open_api.#{locale}.yml"
        end
      end
    end
  end
end
