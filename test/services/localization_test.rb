# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LocalizationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @error_hash1 = {
        path: 'validation.errors.boolean',
        substitutions: {
          data: {
            method: 'number_to_human_size',
            value: 1_000_000
          }
        }
      }
      @german_string1 = I18n.t('validation.errors.boolean', data: '977 KB', locale: :de)
      @english_string1 = I18n.t('validation.errors.boolean', data: '977 KB', locale: :en)
      @error_hash2 = {
        path: 'validation.errors.boolean',
        substitutions: {
          data: {
            path: 'validation.errors.key',
            substitutions: {
              data: {
                method: 'number_to_human_size',
                value: 1_000_000
              }
            }
          }
        }
      }
      @german_string2 = I18n.t('validation.errors.boolean', data: I18n.t('validation.errors.key', data: '977 KB', locale: :de), locale: :de)
      @english_string2 = I18n.t('validation.errors.boolean', data: I18n.t('validation.errors.key', data: '977 KB', locale: :en), locale: :en)
    end

    test 'memoization of view_helpers' do
      assert_equal DataCycleCore::LocalizationService.view_helpers.object_id, DataCycleCore::LocalizationService.view_helpers.object_id
    end

    test 'correctly localize and substitute text' do
      assert_equal @german_string1, DataCycleCore::LocalizationService.translate_and_substitute(@error_hash1, :de)
      assert_equal @english_string1, DataCycleCore::LocalizationService.translate_and_substitute(@error_hash1, :en)

      assert_equal @german_string2, DataCycleCore::LocalizationService.translate_and_substitute(@error_hash2, :de)
      assert_equal @english_string2, DataCycleCore::LocalizationService.translate_and_substitute(@error_hash2, :en)
    end

    test 'correctly localize error messages from validators' do
      translated_string = 'already translated string'
      assert_equal translated_string, DataCycleCore::LocalizationService.localize_validation_errors(translated_string, :de)

      translatable_errors = DataCycleCore::LocalizationService.localize_validation_errors({
        error: @error_hash1,
        warning: @error_hash2
      }, :de)
      expected_errors = { error: @german_string1, warning: @german_string2 }

      assert_equal expected_errors, translatable_errors

      translatable_errors = DataCycleCore::LocalizationService.localize_validation_errors({
        error: { name: @error_hash1 },
        warning: { name: @error_hash2 }
      }, :de)
      expected_errors = { error: { name: @german_string1 }, warning: { name: @german_string2 } }

      assert_equal expected_errors, translatable_errors

      translatable_errors = DataCycleCore::LocalizationService.localize_validation_errors({
        error: [{ name: @error_hash1 }],
        warning: [{ name: @error_hash2 }]
      }, :de)
      expected_errors = { error: [{ name: @german_string1 }], warning: [{ name: @german_string2 }] }

      assert_equal expected_errors, translatable_errors

      translatable_errors = DataCycleCore::LocalizationService.localize_validation_errors({
        error: [@error_hash1],
        warning: [@error_hash2]
      }, :de)
      expected_errors = { error: [@german_string1], warning: [@german_string2] }

      assert_equal expected_errors, translatable_errors

      translatable_errors = DataCycleCore::LocalizationService.localize_validation_errors({
        error: translated_string,
        warning: translated_string
      }, :de)
      expected_errors = { error: translated_string, warning: translated_string }

      assert_equal expected_errors, translatable_errors
    end
  end
end
