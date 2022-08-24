# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      module Functions
        class JsonLdToTranslatedDataHashTest < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'json_ld hash with @value and @language gets transformed and nested' do
            result = DataCycleCore::Generic::Common::Functions.json_ld_to_translated_data_hash({
              'name' => [
                {
                  '@language' => 'de',
                  '@value' => 'value_de'
                },
                {
                  '@language' => 'en',
                  '@value' => 'value_en'
                }
              ]
            })

            assert_equal 'value_de', result.dig(:translations, 'de', 'name')
            assert_equal 'value_en', result.dig(:translations, 'en', 'name')
            assert result.dig(:datahash).blank?
          end

          test 'json_ld hash without @value and @language gets nested and not transformed' do
            result = DataCycleCore::Generic::Common::Functions.json_ld_to_translated_data_hash({
              'name' => 'value_de'
            })

            assert_equal 'value_de', result.dig(:datahash, 'name')
            assert result.dig(:translations).blank?
          end
        end
      end
    end
  end
end
