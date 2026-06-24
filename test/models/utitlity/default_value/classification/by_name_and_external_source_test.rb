# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'

module DataCycleCore
  class DefaultValueClassificationByNameAndExternalSourceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include VirtualAttributeTestUtilities

    before(:all) do
      @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @tag1 = DataCycleCore::Concept.for_tree('Tags').with_internal_name('Tag 1').first
      @tag2 = DataCycleCore::Concept.for_tree('Tags').with_internal_name('Tag 2').first
    end

    def subject
      DataCycleCore::Utility::DefaultValue::Classification
    end

    test 'should take classification for external system by name' do
      content = create_dummy({ name: 'test', external_source: @external_system }, DataCycleCore::Thing)
      value = subject.by_name_and_external_source(property_definition: {
        'tree_label' => 'Tags',
        'default_value' => {
          'value' => {
            @external_system.name => 'Tag 1',
            'default' => 'Tag 2'
          }
        }
      }, content:)

      assert_equal([@tag1.classification_id], value)
    end

    test 'should take classification for external system by identifier' do
      content = create_dummy({ name: 'test', external_source: @external_system }, DataCycleCore::Thing)
      value = subject.by_name_and_external_source(property_definition: {
        'tree_label' => 'Tags',
        'default_value' => {
          'value' => {
            @external_system.identifier => 'Tag 1',
            'default' => 'Tag 2'
          }
        }
      }, content:)

      assert_equal([@tag1.classification_id], value)
    end

    test 'should take classification for default' do
      content = create_dummy({ name: 'test', external_source: nil }, DataCycleCore::Thing)
      value = subject.by_name_and_external_source(property_definition: {
        'tree_label' => 'Tags',
        'default_value' => {
          'value' => {
            @external_system.identifier => 'Tag 1',
            'default' => 'Tag 2'
          }
        }
      }, content:)

      assert_equal([@tag2.classification_id], value)
    end
  end
end
