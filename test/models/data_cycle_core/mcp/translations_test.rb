# frozen_string_literal: true

require 'test_helper'
require 'yaml'

module DataCycleCore
  module Mcp
    # The tree definitions from config/locales/{de,en}.mcp.yml are the only channel through which a
    # client learns WHICH dimension a classification tree represents. The lookup has two properties
    # that are easily lost when rebuilding it and that both fail silently: tree names containing a
    # dot must not be split into an I18n path, and a tree without a definition must return nil (the
    # field is then absent from the response rather than standing there empty).
    class TranslationsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      include DataCycleCore::I18nTestHelper

      # Dots in a name are the normal case, not the exception: trees come mostly from import sources
      # ("Feratel - Orte i. G."). Passed as a string in the scope, I18n split the name at the dots
      # and looked under mcp.concept_schemes.Feratel - Orte i.G -- result nil, i.e. a definition that
      # sits in the locale file but is never delivered.
      DOTTED_NAME = 'Feratel - Orte i. G.'
      DEFINITION = 'Orte in der Gemeinde -- Feratel-eigene Ortsgliederung.'

      # Languages the gem ships MCP translations for. Kept explicit so a newly added, half
      # translated one is caught here rather than reaching a client as "translation missing".
      MCP_LOCALES = [:de, :en].freeze

      test 'a concept scheme description survives dots in the tree name' do
        store(DOTTED_NAME => DEFINITION)

        assert_equal DEFINITION, DataCycleCore::Mcp::Translations.concept_scheme_description(DOTTED_NAME)
      end

      test 'an undocumented tree, a blank definition and a blank name resolve to nil' do
        store('Leerer Baum' => '')

        assert_nil DataCycleCore::Mcp::Translations.concept_scheme_description('Nicht kuratierter Baum')
        assert_nil DataCycleCore::Mcp::Translations.concept_scheme_description('Leerer Baum')
        assert_nil DataCycleCore::Mcp::Translations.concept_scheme_description(nil)
        assert_nil DataCycleCore::Mcp::Translations.concept_scheme_description('')
      end

      # The definition follows the locale passed in, not the one currently active -- the MCP tools
      # determine their locale from the endpoint (SingleEndpointServer#description_locale).
      test 'the requested locale wins over the ambient one' do
        I18n.backend.store_translations(:de, { mcp: { concept_schemes: { Zweisprachig: { description: 'deutsche Definition' } } } })
        I18n.backend.store_translations(:en, { mcp: { concept_schemes: { Zweisprachig: { description: 'english definition' } } } })

        I18n.with_locale(:de) do
          assert_equal 'english definition', DataCycleCore::Mcp::Translations.concept_scheme_description('Zweisprachig', locale: :en)
          assert_equal 'deutsche Definition', DataCycleCore::Mcp::Translations.concept_scheme_description('Zweisprachig')
        end
      end

      # --- guard suite: the two locale files ------------------------------

      # A key in only one file reaches the client as "translation missing" on the mount that runs in
      # the other language -- and no test asks for both, because the suites pick one language each.
      test 'both MCP locale files define the exact same set of keys' do
        reference, *others = MCP_LOCALES
        expected = locale_file_keys(reference)

        others.each do |locale|
          actual = locale_file_keys(locale)

          assert_equal expected, actual,
                       "#{locale}.mcp.yml differs from #{reference}.mcp.yml (only in #{reference}: " \
                       "#{(expected - actual).join(', ')}; only in #{locale}: #{(actual - expected).join(', ')})"
        end
      end

      # A placeholder the other language does not have fails LOUDLY and only there: I18n raises
      # MissingInterpolationArgument on the call, so the tool answers with an error in one language
      # and a text in the other.
      test 'interpolation placeholders are identical across both MCP locale files' do
        reference, *others = MCP_LOCALES
        expected = locale_file_placeholders(reference)

        others.each do |locale|
          assert_equal expected, locale_file_placeholders(locale),
                       "interpolation placeholders differ between #{reference}.mcp.yml and #{locale}.mcp.yml"
        end
      end

      # store_translations writes into the I18n backend's process cache and would otherwise bleed
      # into every following test of the same worker. It is reset to the exact initial state and NOT
      # through I18n.reload!, which would lose the dry-validation error texts injected at boot for
      # good -- rationale in I18nTestHelper.
      setup { snapshot_translations! }
      teardown { restore_translations! }

      private

      # { 'warnings.unresolved_place' => '...' } for one shipped file.
      #
      # Read from disk and not through I18n, whose backend merges every engine's and the project's
      # files into one tree: a key the gem ships in only one language still resolves there as soon
      # as any other file defines it. fetch so that a moved path errors instead of flattening nil.
      def locale_file_translations(locale)
        path = DataCycleCore::Engine.root.join('config', 'locales', "#{locale}.mcp.yml")

        flatten_translations(YAML.safe_load_file(path).fetch(locale.to_s).fetch('mcp'))
      end

      def locale_file_keys(locale)
        locale_file_translations(locale).keys.sort
      end

      def locale_file_placeholders(locale)
        locale_file_translations(locale)
          .transform_values { |value| value.to_s.scan(/%\{(\w+)\}/).flatten.sort }
          .reject { |_key, placeholders| placeholders.empty? }
      end

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

      def store(definitions)
        translations = definitions.transform_keys(&:to_sym).transform_values { |description| { description: } }

        I18n.available_locales.each { |locale| I18n.backend.store_translations(locale, { mcp: { concept_schemes: translations } }) }
      end
    end
  end
end
