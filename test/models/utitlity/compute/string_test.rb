# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class StringTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          tree = DataCycleCore::ClassificationTreeLabel.create!(name: 'Compute String Test Tree')
          child_alias = tree.create_or_update_classification_alias_by_name('CS Parent', { name: 'CS Child', external_key: 'CSC-1' })
          @child_classification_id = child_alias.primary_classification.id
        end

        def subject
          DataCycleCore::Utility::Compute::String
        end

        def child_concept
          DataCycleCore::Concept.for_tree('Compute String Test Tree').find_by(classification_id: @child_classification_id)
        end

        test 'concat joins all flattened parameter values with the configured separator' do
          value = subject.concat(
            computed_parameters: { 'a' => 'foo', 'b' => ['bar', 'baz'] },
            computed_definition: { 'compute' => { 'separator' => ', ' } }
          )

          assert_equal('foo, bar, baz', value)
        end

        test 'concat joins without a separator when none is configured' do
          value = subject.concat(
            computed_parameters: { 'a' => 'foo', 'b' => 'bar' },
            computed_definition: {}
          )

          assert_equal('foobar', value)
        end

        test 'value returns the configured compute value' do
          assert_equal('static', subject.value(computed_definition: { 'compute' => { 'value' => 'static' } }))
          assert_nil(subject.value(computed_definition: {}))
        end

        test 'interpolate formats the configured template with parameters and content metadata' do
          content = struct_double(created_at: Time.zone.now, external_key: 'EXT-1')
          value = subject.interpolate(
            computed_parameters: { 'name' => 'World' },
            content:,
            computed_definition: { 'compute' => { 'value' => '%<external_key>s: Hello %<name>s' } }
          )

          assert_equal('EXT-1: Hello World', value)
        end

        test 'interpolate_outdoor_active_tour_url prefers content metadata over parameters' do
          content = struct_double(external_key: 'TOUR-1', external_source: struct_double(default_options: { 'outdoor_active_tour_base_url' => 'https://oa.test' }))
          value = subject.interpolate_outdoor_active_tour_url(
            computed_parameters: { 'external_key' => 'IGNORED' },
            content:,
            computed_definition: { 'compute' => { 'value' => '%<outdoor_active_tour_base_url>s/tour/%<external_key>s' } }
          )

          assert_equal('https://oa.test/tour/TOUR-1', value)
        end

        test 'interpolate_outdoor_active_poi_url builds a poi url from content metadata' do
          content = struct_double(external_key: 'POI-1', external_source: struct_double(default_options: { 'outdoor_active_poi_base_url' => 'https://oa.test' }))
          value = subject.interpolate_outdoor_active_poi_url(
            computed_parameters: {},
            content:,
            computed_definition: { 'compute' => { 'value' => '%<outdoor_active_poi_base_url>s/poi/%<external_key>s' } }
          )

          assert_equal('https://oa.test/poi/POI-1', value)
        end

        test 'number_of_characters sums stripped character counts across the configured paths' do
          value = subject.number_of_characters(
            data_hash: { 'name' => '<b>hello</b>', 'description' => 'world' },
            computed_definition: { 'compute' => { 'paths' => ['name', 'description'] } }
          )

          assert_equal(10, value)
        end

        test 'number_of_characters reads from the current locale translations' do
          I18n.with_locale(:de) do
            value = subject.number_of_characters(
              data_hash: { 'translations' => { 'de' => { 'name' => 'abcde' } } },
              computed_definition: { 'compute' => { 'paths' => ['name'] } }
            )

            assert_equal(5, value)
          end
        end

        test 'number_of_characters recurses into nested embedded paths' do
          value = subject.number_of_characters(
            data_hash: { 'overlays' => [{ 'name' => 'abcd' }, { 'name' => 'ef' }] },
            computed_definition: { 'compute' => { 'paths' => [{ 'overlays' => ['name'] }] } }
          )

          assert_equal(6, value)
        end

        test 'number_of_characters returns nil when paths are blank' do
          assert_nil(subject.number_of_characters(data_hash: { 'name' => 'x' }, computed_definition: {}))
        end

        test 'linked_gip_route_attribute reads an attribute from the linked thing' do
          DataCycleCore::Thing.stub(:find_by, struct_double(route_name: 'GIP Route 7')) do
            value = subject.linked_gip_route_attribute(
              computed_parameters: { 'linked' => 'thing-id' },
              computed_definition: { 'compute' => { 'linked_attribute' => 'route_name' } }
            )

            assert_equal('GIP Route 7', value)
          end
        end

        test 'classification_name returns the matching concept name' do
          definition = { 'compute' => { 'tree_label' => 'Compute String Test Tree' } }
          value = subject.classification_name(computed_parameters: { 'c' => [@child_classification_id] }, computed_definition: definition)

          assert_equal(child_concept.name, value)
        end

        test 'classification_name returns nil for blank classifications or tree label' do
          assert_nil(subject.classification_name(computed_parameters: { 'c' => [] }, computed_definition: { 'compute' => { 'tree_label' => 'Tags' } }))
          assert_nil(subject.classification_name(computed_parameters: { 'c' => [@child_classification_id] }, computed_definition: { 'compute' => {} }))
        end

        test 'parent_classification_name returns the parent concept name' do
          definition = { 'compute' => { 'tree_label' => 'Compute String Test Tree' } }
          value = subject.parent_classification_name(computed_parameters: { 'c' => [@child_classification_id] }, computed_definition: definition)

          assert_equal(child_concept.parent.name, value)
        end

        test 'parent_classification_name returns nil for blank classifications or tree label' do
          assert_nil(subject.parent_classification_name(computed_parameters: { 'c' => [] }, computed_definition: { 'compute' => { 'tree_label' => 'Tags' } }))
          assert_nil(subject.parent_classification_name(computed_parameters: { 'c' => [@child_classification_id] }, computed_definition: { 'compute' => {} }))
        end
      end
    end
  end
end
