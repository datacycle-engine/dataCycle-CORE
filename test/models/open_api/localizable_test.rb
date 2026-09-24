# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module OpenApi
    # Unit tests for the Localizable mixin: the shared `t` helper that the
    # stateless OpenAPI builder modules `extend` so they can localize strings
    # inside `module_function` definitions. These tests only cover the mixin's
    # own contract (it exposes `t` and delegates verbatim to Translations); the
    # actual i18n resolution/interpolation is covered by TranslationsTest.
    class LocalizableTest < ActiveSupport::TestCase
      # Builder-style module that mixes in Localizable exactly like the real
      # paths/components/schemas modules do.
      def builder
        Module.new do
          extend DataCycleCore::OpenApi::Localizable

          module_function

          # proves `t` is reachable from within a module_function definition —
          # the whole reason the mixin exists.
          def not_found = t('responses.not_found')

          def entity_type(types) = t('schemas.entity_type', types:)
        end
      end

      test 'extending a module exposes the t helper' do
        assert_respond_to builder, :t
      end

      test 't delegates verbatim to Translations.t for the ambient locale' do
        [:en, :de].each do |locale|
          I18n.with_locale(locale) do
            assert_equal Translations.t('responses.not_found'), builder.t('responses.not_found')
          end
        end
      end

      test 't is callable from inside a module_function definition' do
        mod = builder

        I18n.with_locale(:en) do
          assert_equal Translations.t('responses.not_found'), mod.not_found
        end
      end

      test 't forwards interpolation variables' do
        mod = builder

        I18n.with_locale(:en) do
          assert_equal Translations.t('schemas.entity_type', types: 'Foo, Bar'), mod.entity_type('Foo, Bar')
        end
      end

      test 't forwards an explicit locale option over the ambient locale' do
        I18n.with_locale(:en) do
          assert_equal Translations.t('responses.not_found', locale: :de), builder.t('responses.not_found', locale: :de)
        end
      end
    end
  end
end
