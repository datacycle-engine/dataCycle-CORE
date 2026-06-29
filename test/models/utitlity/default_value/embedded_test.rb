# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class EmbeddedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::Embedded
        end

        test 'gip_start_end_waypoints returns the fixed start/end waypoints' do
          assert_equal([{ name: 'Start' }, { name: 'Ende' }], subject.gip_start_end_waypoints)
        end

        test 'by_name_value_source maps classification names to ids for an array value definition' do
          property_definition = {
            'template_name' => 'TestTemplate',
            'default_value' => { 'value' => [{ 'tags' => 'Tag 1' }] }
          }

          value = with_embedded_stubs do
            subject.by_name_value_source(content: nil, property_definition:)
          end

          assert_equal([{ 'tags' => ['cid-1'], 'template_name' => 'TestTemplate' }], value)
        end

        test 'by_name_value_source picks the internal value set for non-external content' do
          property_definition = {
            'template_name' => 'TestTemplate',
            'default_value' => { 'value' => { 'internal' => [{ 'tags' => 'Tag 1' }], 'external' => [] } }
          }
          content = Class.new { def external? = false }.new

          value = with_embedded_stubs do
            subject.by_name_value_source(content:, property_definition:)
          end

          assert_equal([{ 'tags' => ['cid-1'], 'template_name' => 'TestTemplate' }], value)
        end

        private

        def template_thing_double
          Class.new {
            def classification_property_names = ['tags']
            def properties_for(_key) = { 'tree_label' => 'Tags' }
          }.new
        end

        def concept_relation_double
          Class.new {
            def where(*_args) = self
            def pluck(_attribute) = ['cid-1']
          }.new
        end

        def with_embedded_stubs(&block)
          template = Struct.new(:template_name, :template_thing).new('TestTemplate', template_thing_double)

          DataCycleCore::ThingTemplate.stub(:where, [template]) do
            DataCycleCore::Concept.stub(:for_tree, concept_relation_double, &block)
          end
        end
      end
    end
  end
end
