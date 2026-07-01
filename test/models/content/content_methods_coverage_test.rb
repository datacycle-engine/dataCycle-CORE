# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    # Coverage for assorted DataCycleCore::Content::Content accessors, the
    # validate_template! error branches and the set_memoized_attribute relation
    # dispatch. Driven mostly by unsaved Thing instances (template-only, no DB).
    class ContentMethodsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @poi = DataCycleCore::Thing.new(template_name: 'POI')
        @persisted_poi_id = DataCycleCore::TestPreparations.create_content(
          template_name: 'POI',
          data_hash: { 'name' => 'Content Methods Coverage POI' }
        ).id
      end

      test 'property-name selectors and simple predicates execute' do
        assert_kind_of(Array, @poi.aggregate_property_names_for('location'))
        assert_kind_of(Array, @poi.dummy_property_names)
        assert_kind_of(Array, @poi.translatable_string_property_names)
        assert_kind_of(Array, @poi.untranslatable_string_property_names)
        assert_kind_of(Array, @poi.table_property_names)
        assert_kind_of(Array, @poi.oembed_property_names)
        assert_kind_of(Array, @poi.opening_time_property_names)
        assert_kind_of(Array, @poi.external_property_names)
        assert_kind_of(Array, @poi.relation_property_names)
        assert_kind_of(Array, @poi.translatable_embedded_property_names)
        assert_includes([true, false], @poi.container?)
        assert_predicate(@poi, :thing_template?)
      end

      test 'changes and saved_changes? merge datahash changes' do
        assert_kind_of(Hash, @poi.changes)
        assert_includes([true, false], @poi.saved_changes?)
      end

      test 'attribute_to_h raises for a property of an unknown type' do
        assert_raises(StandardError) { @poi.attribute_to_h('definitely_not_a_real_property') }
      end

      # ---- validate_template! error branches ----

      test 'validate_template! raises when the named template does not exist' do
        # Reachable only on a persisted record whose template_name is changed to a
        # missing template (Thing.new always co-assigns thing_template, so the
        # constructor can never reach this branch).
        poi = DataCycleCore::Thing.find(@persisted_poi_id)

        error = assert_raises(ActiveModel::MissingAttributeError) do
          poi.template_name = 'NonExistentTemplate123'
        end

        assert_match(/does not exist/, error.message)
      end

      # ---- set_memoized_attribute relation dispatch ----

      test 'set_memoized_attribute dispatches asset properties' do
        thing = DataCycleCore::Thing.new(template_name: 'Bild')

        assert_nothing_raised { thing.set_memoized_attribute('asset', []) }
        assert(thing.instance_variable_defined?(:@get_property_value))
      end

      test 'set_memoized_attribute dispatches schedule properties' do
        thing = DataCycleCore::Thing.new(template_name: 'Öffnungszeit - Beschreibung')

        assert_nothing_raised { thing.set_memoized_attribute('validity_schedule', []) }
        assert(thing.instance_variable_defined?(:@get_property_value))
      end

      test 'set_memoized_attribute dispatches timeseries properties' do
        thing = DataCycleCore::Thing.new(template_name: 'Timeseries')

        assert_nothing_raised { thing.set_memoized_attribute('series', []) }
        assert(thing.instance_variable_defined?(:@get_property_value))
      end

      test 'set_memoized_attribute dispatches collection properties' do
        thing = DataCycleCore::Thing.new(template_name: 'Entity-With-Collection-Link')

        assert_nothing_raised { thing.set_memoized_attribute('collections', []) }
        assert(thing.instance_variable_defined?(:@get_property_value))
      end
    end
  end
end
