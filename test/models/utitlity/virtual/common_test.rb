# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class CommonTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Virtual Common Thing' })
        end

        def subject
          DataCycleCore::Utility::Virtual::Common
        end

        test 'value_from_definition digs the property definition path' do
          content = struct_double(property_definitions: { 'a' => { 'b' => 'deep-value' } })

          assert_equal('deep-value', subject.value_from_definition(virtual_definition: { 'virtual' => { 'path' => ['a', 'b'] } }, content:))
        end

        test 'value_from_definition returns nil for a blank path' do
          assert_nil(subject.value_from_definition(virtual_definition: { 'virtual' => {} }, content: struct_double(property_definitions: {})))
        end

        test 'attribute_value_by_first_match returns the first present configured value' do
          content = struct_double(first_available_locale: :de, name: 'Headline')
          definition = { 'virtual' => { 'value' => [{ 'attribute' => 'name' }] } }

          assert_equal('Headline', subject.attribute_value_by_first_match(virtual_definition: definition, content:))
        end

        test 'get_value_by_filter recurses into embedded paths until it finds a value' do
          child = struct_double(first_available_locale: :de, name: 'Child Value')
          content = embedded_content([child])

          value = subject.send(:get_value_by_filter, content, ['overlays', 'name'], nil)

          assert_equal('Child Value', value)
        end

        test 'get_value_by_filter returns nil when the key is not a relation property' do
          content = embedded_content('present')

          assert_nil(subject.send(:get_value_by_filter, content, ['unknown', 'deep'], nil))
        end

        test 'get_value_by_filter returns nil when no embedded value matches' do
          content = embedded_content([])

          assert_nil(subject.send(:get_value_by_filter, content, ['overlays', 'name'], nil))
        end

        test 'get_value_by_filter applies a filter to the resolved data' do
          content = struct_double(first_available_locale: :de, name: 'Filtered')

          value = subject.send(:get_value_by_filter, content, ['name'], [{ 'type' => 'content_type', 'value' => 'X' }])

          assert_equal('Filtered', value)
        end

        test 'overlay merges object override values onto the original value' do
          override_param = "data#{base_overlay_postfix}"
          content = struct_double(**{ data: { 'a' => 1 }, override_param.to_sym => { 'b' => 2 } })

          DataCycleCore::MasterData::Templates::Extensions::Overlay.stub(:allowed_postfixes_for_type, [base_overlay_postfix, add_overlay_postfix]) do
            value = subject.overlay(virtual_parameters: ['data', override_param], content:, virtual_definition: { 'type' => 'object' })

            assert_equal({ 'a' => 1, 'b' => 2 }, value)
          end
        end

        test 'content_in_filter? is true for a blank key' do
          assert(subject.send(:content_in_filter?, struct_double(content_type: 'Artikel'), [{ 'type' => 'content_type', 'value' => 'X' }], nil))
        end

        test 'content_in_filter? matches a classification filter' do
          relation = Class.new {
            def joins(_association) = self
            def exists?(_condition) = true
          }.new
          content = struct_double(classification_aliases: relation)

          assert(subject.send(:content_in_filter?, content, [{ 'type' => 'classification', 'value' => 'Lizenzen > CC0' }], 'license'))
        end

        test 'content_in_filter? is false when a non-classification filter does not match' do
          content = struct_double(content_type: 'Artikel')

          assert_not(subject.send(:content_in_filter?, content, [{ 'type' => 'content_type', 'value' => 'Event' }], 'name'))
        end

        test 'filtered_data returns the data unchanged when blank' do
          assert_nil(subject.send(:filtered_data, data: nil, filter: [], key: 'name'))
        end

        test 'filtered_data keeps a single matching ActiveRecord content' do
          filter = [{ 'type' => 'content_type', 'value' => @thing.content_type }]

          assert_equal(@thing, subject.send(:filtered_data, data: @thing, filter:, key: 'name'))
        end

        test 'filtered_data selects the matching contents from a relation' do
          filter = [{ 'type' => 'content_type', 'value' => @thing.content_type }]
          relation = DataCycleCore::Thing.where(id: @thing.id)

          result = subject.send(:filtered_data, data: relation, filter:, key: 'name')

          assert_equal([@thing.id], result.pluck(:id))
        end

        private

        def base_overlay_postfix
          DataCycleCore::MasterData::Templates::Extensions::Overlay::BASE_OVERLAY_POSTFIX
        end

        def add_overlay_postfix
          DataCycleCore::MasterData::Templates::Extensions::Overlay::ADD_OVERLAY_POSTFIX
        end

        def embedded_content(overlays_value)
          Class.new {
            def initialize(overlays) = (@overlays = overlays)
            def first_available_locale = :de
            def try(key) = key.to_s == 'overlays' ? @overlays : nil
            def embedded_property_names = ['overlays']
            def linked_property_names = []
            def classification_property_names = []
          }.new(overlays_value)
        end
      end
    end
  end
end
