# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class AssetTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::Asset
        end

        # --- file_type_classification ---------------------------------------

        test 'file_type_classification delegates to the compute asset module' do
          DataCycleCore::Utility::Compute::Asset.stub(:file_type_classification, ['ft-1']) do
            value = subject.file_type_classification(
              property_parameters: { 'a' => 'asset-1' },
              property_definition: { 'tree_label' => 'File Types' },
              content: nil,
              data_hash: {},
              key: 'file_type'
            )

            assert_equal(['ft-1'], value)
          end
        end

        # --- color_space_classification -------------------------------------

        test 'color_space_classification returns [] when the asset has no color space' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: {})) do
            value = subject.color_space_classification(property_parameters: { 'a' => 'asset-1' }, property_definition: { 'tree_label' => 'Color Spaces' })

            assert_equal([], value)
          end
        end

        test 'color_space_classification wraps an existing classification candidate' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'ImColorSpace' => 'sRGB' })) do
            DataCycleCore::ClassificationAlias.stub(:classification_for_tree_with_name, 'cs-existing') do
              value = subject.color_space_classification(property_parameters: { 'a' => 'asset-1' }, property_definition: { 'tree_label' => 'Color Spaces' })

              assert_equal(['cs-existing'], value)
            end
          end
        end

        test 'color_space_classification creates a classification when no candidate exists' do
          tree_label = classification_tree_label_double('cs-new')

          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'ImColorSpace' => 'sRGB' })) do
            DataCycleCore::ClassificationAlias.stub(:classification_for_tree_with_name, nil) do
              DataCycleCore::ClassificationTreeLabel.stub(:find_by, tree_label) do
                value = subject.color_space_classification(property_parameters: { 'a' => 'asset-1' }, property_definition: { 'tree_label' => 'Color Spaces' })

                assert_equal(['cs-new'], value)
              end
            end
          end
        end

        # --- exif_to_classification -----------------------------------------

        test 'exif_to_classification maps exif metadata to existing classification ids' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'Keywords' => ['Alpha', 'Beta'] })) do
            DataCycleCore::ClassificationAlias.stub(:classifications_for_tree_with_name, ['kw-1', 'kw-2']) do
              value = subject.exif_to_classification(
                property_parameters: { 'a' => 'asset-1' },
                property_definition: { 'tree_label' => 'Keywords', 'default_value' => { 'options' => { 'metadata' => ['Keywords'] } } },
                content: struct_double(local_import: false)
              )

              assert_equal(['kw-1', 'kw-2'], value)
            end
          end
        end

        test 'exif_to_classification falls back to the configured default value' do
          mapping = ->(_tree, value) { value == 'Fallback' ? ['kw-default'] : [] }

          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'Keywords' => ['Alpha'] })) do
            DataCycleCore::ClassificationAlias.stub(:classifications_for_tree_with_name, mapping) do
              value = subject.exif_to_classification(
                property_parameters: { 'a' => 'asset-1' },
                property_definition: { 'tree_label' => 'Keywords', 'default_value' => { 'options' => { 'metadata' => ['Keywords'], 'default' => 'Fallback' } } },
                content: struct_double(local_import: false)
              )

              assert_equal(['kw-default'], value)
            end
          end
        end

        test 'exif_to_classification creates classifications and prefers the import default when locally imported' do
          tree_label = classification_tree_label_double('kw-created')

          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'Keywords' => ['Alpha'] })) do
            DataCycleCore::ClassificationTreeLabel.stub(:find_by, tree_label) do
              value = subject.exif_to_classification(
                property_parameters: { 'a' => 'asset-1' },
                property_definition: { 'tree_label' => 'Keywords', 'default_value' => { 'options' => { 'metadata' => ['Keywords'], 'create' => true, 'default_import' => 'ImportDefault' } } },
                content: struct_double(local_import: true)
              )

              assert_equal(['kw-created'], value)
            end
          end
        end

        # --- exif_to_string / filename_to_string / exif_to_headline ---------

        test 'exif_to_string joins array metadata values' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'Keywords' => ['Alpha', 'Beta'] })) do
            value = subject.exif_to_string(
              property_parameters: { 'a' => 'asset-1' },
              property_definition: { 'default_value' => { 'options' => { 'metadata' => ['Keywords'] } } }
            )

            assert_equal('Alpha, Beta', value)
          end
        end

        test 'exif_to_string returns nil without metadata' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: {})) do
            assert_nil(subject.exif_to_string(
                         property_parameters: { 'a' => 'asset-1' },
                         property_definition: { 'default_value' => { 'options' => { 'metadata' => ['Keywords'] } } }
                       ))
          end
        end

        test 'filename_to_string returns the asset name' do
          DataCycleCore::Asset.stub(:find_by, struct_double(name: 'photo.jpg')) do
            assert_equal('photo.jpg', subject.filename_to_string(property_parameters: { 'a' => 'asset-1' }))
          end
        end

        test 'exif_to_headline returns the exif string when present' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'Headline' => 'My Headline' }, name: 'photo.jpg')) do
            value = subject.exif_to_headline(
              property_parameters: { 'a' => 'asset-1' },
              property_definition: { 'default_value' => { 'options' => { 'metadata' => ['Headline'] } } }
            )

            assert_equal('My Headline', value)
          end
        end

        test 'exif_to_headline falls back to the filename when no exif headline exists' do
          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: {}, name: 'photo.jpg')) do
            value = subject.exif_to_headline(
              property_parameters: { 'a' => 'asset-1' },
              property_definition: { 'default_value' => { 'options' => { 'metadata' => ['Headline'] } } }
            )

            assert_equal('photo.jpg', value)
          end
        end

        # --- exif_to_linked -------------------------------------------------

        test 'exif_to_linked returns the linked thing id matched via the stored filter' do
          stored_filter = stored_filter_double(struct_double(id: 'thing-1'))

          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'ManagedBy' => ['Org'] })) do
            DataCycleCore::StoredFilter.stub(:new, stored_filter) do
              value = subject.exif_to_linked(
                property_parameters: { 'a' => 'asset-1' },
                property_definition: { 'stored_filter' => {}, 'default_value' => { 'options' => { 'metadata' => ['ManagedBy'] } } },
                content: struct_double(local_import: false)
              )

              assert_equal(['thing-1'], value)
            end
          end
        end

        test 'exif_to_linked falls back to the configured default when nothing matches' do
          stored_filter = stored_filter_double(nil)

          DataCycleCore::Asset.stub(:find_by, struct_double(metadata: { 'ManagedBy' => 'Org' })) do
            DataCycleCore::StoredFilter.stub(:new, stored_filter) do
              value = subject.exif_to_linked(
                property_parameters: { 'a' => 'asset-1' },
                property_definition: { 'stored_filter' => {}, 'default_value' => { 'options' => { 'metadata' => ['ManagedBy'], 'default_import' => 'fallback-id' } } },
                content: struct_double(local_import: true)
              )

              assert_equal('fallback-id', value)
            end
          end
        end

        private

        # tree_label whose #create_classification_alias(value).primary_classification.id == id
        def classification_tree_label_double(id)
          created = Struct.new(:primary_classification).new(Struct.new(:id).new(id))
          Struct.new(:alias_double) {
            def create_classification_alias(_value) = alias_double
          }.new(created)
        end

        # stored filter whose chained query returns the given record from #first
        def stored_filter_double(result)
          Struct.new(:result) {
            def parameters_from_hash(_hash) = self
            def apply = self
            def equals_advanced_translated_name(_value) = self
            def first = result
          }.new(result)
        end
      end
    end
  end
end
