# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Utility
    module Virtual
      module String
        class ClassificationValueTest < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @tree = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: 'TestHeadlineLevels')
            @h2 = @tree.create_classification_alias({ name: 'H2', external_key: 'h2' })

            # a second tree the test content is NOT classified in, for the nil case
            @unassigned_tree = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: 'TestFontColor')
            @unassigned_tree.create_classification_alias({ name: 'Light', external_key: 'light' })

            image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image').deep_dup
            image_data_hash['universal_classifications'] = [@h2.primary_classification.id]
            @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)
          end

          def virtual_definition(tree_label:, key: nil)
            { 'virtual' => { 'tree_label' => tree_label, 'key' => key }.compact }
          end

          test 'returns the external_key of the selected classification' do
            assert_equal(
              'h2',
              DataCycleCore::Utility::Virtual::String.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestHeadlineLevels', key: 'external_key')
              )
            )
          end

          test 'defaults to external_key when no key is given' do
            assert_equal(
              'h2',
              DataCycleCore::Utility::Virtual::String.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestHeadlineLevels')
              )
            )
          end

          test 'can read a different key (internal_name)' do
            assert_equal(
              'H2',
              DataCycleCore::Utility::Virtual::String.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestHeadlineLevels', key: 'internal_name')
              )
            )
          end

          test 'returns nil when the content has no classification for the tree' do
            assert_nil(
              DataCycleCore::Utility::Virtual::String.classification_value(
                content: @image,
                virtual_definition: virtual_definition(tree_label: 'TestFontColor')
              )
            )
          end

          test 'returns nil when tree_label is blank' do
            assert_nil(
              DataCycleCore::Utility::Virtual::String.classification_value(
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
