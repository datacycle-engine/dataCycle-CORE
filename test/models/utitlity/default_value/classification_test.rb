# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class ClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @tag1 = DataCycleCore::Concept.for_tree('Tags').with_internal_name('Tag 1').first
        end

        def subject
          DataCycleCore::Utility::DefaultValue::Classification
        end

        test 'by_name resolves a hash default_value to its concept ids' do
          value = subject.by_name(property_definition: {
            'tree_label' => 'Tags',
            'default_value' => { 'value' => 'Tag 1' }
          })

          assert_equal([@tag1.classification_id], value)
        end

        test 'schema_types concatenates the classifications resolved from the content schema type' do
          content = struct_double(schema_ancestors: [], schema_type: 'CreativeWork', template_name: 'Artikel')

          subject.stub(:find_classification, ['cid-schema']) do
            value = subject.schema_types(property_definition: { 'tree_label' => 'SchemaTypes' }, content:)

            assert_equal(['cid-schema'], value)
          end
        end

        test 'by_user_and_name resolves the concept for the current user role' do
          current_user = struct_double(role: struct_double(name: 'administrator'))
          value = subject.by_user_and_name(property_definition: {
            'tree_label' => 'Tags',
            'default_value' => { 'value' => { 'administrator' => 'Tag 1' } }
          }, current_user:)

          assert_equal([@tag1.classification_id], value)
        end

        test 'by_user_and_concept_id resolves the concept id for the current user role' do
          current_user = struct_double(role: struct_double(name: 'unmapped'))
          value = subject.by_user_and_concept_id(property_definition: {
            'default_value' => { 'value' => { 'all' => @tag1.id } }
          }, current_user:)

          assert_equal([@tag1.classification_id], value)
        end

        test 'by_user_or_group_and_name resolves the concept for the current user role' do
          current_user = struct_double(role: struct_double(name: 'administrator'), user_groups: nil)
          value = subject.by_user_or_group_and_name(property_definition: {
            'tree_label' => 'Tags',
            'default_value' => { 'value' => { 'administrator' => 'Tag 1' } }
          }, current_user:)

          assert_equal([@tag1.classification_id], value)
        end

        test 'copy_from_string resolves classification ids from the configured data_hash values' do
          value = subject.copy_from_string(
            property_definition: { 'tree_label' => 'Tags', 'default_value' => { 'parameters' => ['name'] }, 'validations' => { 'max' => 1 } },
            data_hash: { 'name' => 'Tag 1' }
          )

          assert_equal([@tag1.classification_id], value)
        end
      end
    end
  end
end
