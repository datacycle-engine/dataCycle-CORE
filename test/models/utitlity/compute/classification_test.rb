# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class ClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @tag_ids = DataCycleCore::Concept.for_tree('Tags').with_name(['Tag 1', 'Tag 2']).pluck(:classification_id)
        end

        def subject
          DataCycleCore::Utility::Compute::Classification
        end

        test 'value resolves classifications for the configured tree and value' do
          DataCycleCore::ClassificationAlias.stub(:classifications_for_tree_with_name, ['classification-id']) do
            value = subject.value(computed_definition: { 'compute' => { 'tree' => 'Tags', 'value' => 'Tag 1' } })

            assert_equal(['classification-id'], value)
          end
        end

        test 'value returns nil when the tree or value is blank' do
          assert_nil(subject.value(computed_definition: { 'compute' => { 'tree' => 'Tags' } }))
          assert_nil(subject.value(computed_definition: { 'compute' => { 'value' => 'Tag 1' } }))
        end

        test 'copy_from_path collects and de-duplicates values from the configured paths' do
          value = subject.copy_from_path(
            computed_parameters: { 'a' => ['x', 'y'], 'b' => ['y', 'z'] },
            computed_definition: { 'compute' => { 'parameters' => ['a', 'b'] } }
          )

          assert_equal(['x', 'y', 'z'], value)
        end

        test 'from_embedded collects classification ids from embedded paths' do
          value = subject.from_embedded(
            computed_parameters: { 'offers' => [{ 'classification' => ['cid-1'] }, { 'classification' => ['cid-2'] }] },
            computed_definition: { 'compute' => { 'parameters' => ['offers.classification'] } }
          )

          assert_equal(['cid-1', 'cid-2'], value)
        end

        test 'from_geo_shape resolves classifications intersecting a geometry string' do
          value = subject.from_geo_shape(
            computed_parameters: { 'geo' => 'POINT (14.5 46.5)' },
            computed_definition: { 'tree_label' => 'Tags', 'compute' => { 'parameters' => ['geo'] } }
          )

          assert_equal([], value)
        end

        test 'from_geo_shape resolves classifications from a geographic object' do
          point = DataCycleCore::MasterData::DataConverter.string_to_geographic('POINT (14.5 46.5)')

          value = subject.from_geo_shape(
            computed_parameters: { 'geo' => point },
            computed_definition: { 'tree_label' => 'Tags', 'compute' => { 'parameters' => ['geo'] } }
          )

          assert_equal([], value)
        end

        test 'from_geo_shape returns nil when classification concepts have no polygons' do
          value = subject.from_geo_shape(
            computed_parameters: { 'areas' => @tag_ids },
            computed_definition: { 'tree_label' => 'Tags', 'compute' => { 'parameters' => ['areas'] } }
          )

          assert_nil(value)
        end

        test 'copy_from_path_for_tree_label returns nil for a blank tree label or empty values' do
          assert_nil(subject.copy_from_path_for_tree_label(computed_parameters: {}, computed_definition: { 'compute' => { 'parameters' => ['a'] } }))
          assert_nil(subject.copy_from_path_for_tree_label(computed_parameters: { 'a' => [] }, computed_definition: { 'tree_label' => 'Tags', 'compute' => { 'parameters' => ['a'] } }))
        end

        test 'copy_from_path_for_tree_label filters concepts by their concept scheme name' do
          # The given concepts belong to "Tags", so a non-matching tree_label filters them all out.
          value = subject.copy_from_path_for_tree_label(
            computed_parameters: { 'a' => @tag_ids },
            computed_definition: { 'tree_label' => 'No Such Concept Scheme', 'compute' => { 'parameters' => ['a'] } }
          )

          assert_equal([], value)
        end

        test 'by_concept_scheme_and_mapping maps source concepts onto the target scheme' do
          value = subject.by_concept_scheme_and_mapping(
            computed_parameters: { 'status' => @tag_ids },
            computed_definition: { 'compute' => { 'source_concept_scheme' => 'Tags', 'concept_scheme' => 'Tags', 'mapping' => {} } }
          )

          assert_equal(@tag_ids.sort, value.sort)
        end

        test 'by_concept_scheme_and_mapping returns nil for blank ids' do
          assert_nil(subject.by_concept_scheme_and_mapping(
                       computed_parameters: { 'status' => [] },
                       computed_definition: { 'compute' => { 'concept_scheme' => 'Tags' } }
                     ))
        end

        test 'from_embedded_by_concept_scheme resolves embedded classifications restricted to a scheme' do
          value = subject.from_embedded_by_concept_scheme(
            computed_parameters: { 'offers' => [{ 'classification' => @tag_ids }] },
            computed_definition: { 'tree_label' => 'Tags', 'compute' => { 'key_path' => 'offers.classification' } }
          )

          assert_equal(@tag_ids.sort, value.sort)
        end

        test 'from_embedded_by_concept_scheme returns an empty array for a blank key path or tree label' do
          assert_equal([], subject.from_embedded_by_concept_scheme(
                             computed_parameters: {},
                             computed_definition: { 'tree_label' => 'Tags', 'compute' => { 'key_path' => '' } }
                           ))
        end

        test 'from_string_for_path returns nil for a blank tree label' do
          assert_nil(subject.from_string_for_path(computed_parameters: {}, computed_definition: { 'compute' => { 'parameters' => ['a'] } }))
        end
      end
    end
  end
end
