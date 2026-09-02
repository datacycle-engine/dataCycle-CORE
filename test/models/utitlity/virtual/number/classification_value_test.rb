# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Utility
    module Virtual
      module Number
        class ClassificationValueTest < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @tree = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: 'TestColumnCounts')
            @two_columns = @tree.create_classification_alias({ name: '2 Spalten', external_key: 'test-columns-2' })

            # a second tree the test content is NOT classified in, for the nil case
            @unassigned_tree = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: 'TestRowCounts')
            @unassigned_tree.create_classification_alias({ name: '1 Zeile', external_key: 'test-rows-1' })

            image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image').deep_dup
            image_data_hash['universal_classifications'] = [@two_columns.primary_classification.id]
            @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)
          end

          def virtual_definition(tree_label:, key: nil)
            { 'virtual' => { 'tree_label' => tree_label, 'key' => key }.compact }
          end

          test 'returns the number in the external_key of the selected classification' do
            assert_equal(
              2,
              DataCycleCore::Utility::Virtual::Number.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestColumnCounts', key: 'external_key')
              )
            )
          end

          test 'defaults to external_key when no key is given' do
            assert_equal(
              2,
              DataCycleCore::Utility::Virtual::Number.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestColumnCounts')
              )
            )
          end

          test 'can read a different key (name)' do
            assert_equal(
              2,
              DataCycleCore::Utility::Virtual::Number.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestColumnCounts', key: 'internal_name')
              )
            )
          end

          test 'returns nil when the content has no classification for the tree' do
            assert_nil(
              DataCycleCore::Utility::Virtual::Number.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestRowCounts')
              )
            )
          end

          test 'returns nil when tree_label is blank' do
            assert_nil(
              DataCycleCore::Utility::Virtual::Number.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: nil)
              )
            )
          end
        end
      end
    end
  end
end
