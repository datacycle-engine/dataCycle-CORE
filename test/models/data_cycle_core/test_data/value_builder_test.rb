# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module TestData
    # Unit tests for the type -> value dispatch. The scalar/structural types are exercised
    # against crafted property definitions with no database access; the database-backed types
    # (classification/asset/linked/embedded) stub their lookup boundary so the tests stay fast
    # and deterministic.
    class ValueBuilderTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # Chainable stand-in for an ActiveRecord relation: scopes return self, pluck returns the ids.
      class FakeRelation
        def initialize(ids)
          @ids = ids
        end

        def assignable = self
        def limit(_count) = self
        def pluck(_column) = @ids
      end

      # Asset source double: returns a configured id per asset type, nil for anything else.
      class FakeAssetSource
        def initialize(ids = {})
          @ids = ids
        end

        def id_for(asset_type) = @ids[asset_type]
      end

      # --- strings -------------------------------------------------------------

      test 'string respects both min and max length' do
        value = build_value({ 'type' => 'string', 'validations' => { 'min' => 40, 'max' => 60 } })

        assert_kind_of String, value
        assert_includes 40..60, value.length
      end

      test 'string with only a max bound is truncated' do
        value = build_value({ 'type' => 'string', 'validations' => { 'max' => 10 } })

        assert_includes 1..10, value.length
      end

      test 'text type is treated like a string' do
        value = build_value({ 'type' => 'text', 'validations' => { 'min' => 20 } })

        assert_kind_of String, value
        assert_operator value.length, :>=, 20
      end

      test 'string format uuid yields a uuid' do
        value = build_value({ 'type' => 'string', 'validations' => { 'format' => 'uuid' } })

        assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, value)
      end

      test 'string format url yields an absolute url' do
        value = build_value({ 'type' => 'string', 'validations' => { 'format' => 'url' } })

        assert value.start_with?('https://')
      end

      test 'string with an unsupported format is skipped, not raised' do
        result = build_result({ 'type' => 'string', 'validations' => { 'format' => 'email' } })

        assert_empty result[:data]
        assert_equal 1, result[:skipped].size
        assert_match(/unsupported format/, result[:skipped].first[:reason])
      end

      test 'string pattern returns a value that fully matches the pattern' do
        value = build_value({ 'type' => 'string', 'validations' => { 'pattern' => '/\A\d{2}:\d{2}\z/' } })

        assert_match(/\A\d{2}:\d{2}\z/, value)
      end

      test 'string with an unsatisfiable pattern is skipped, not raised' do
        result = build_result({ 'type' => 'string', 'validations' => { 'pattern' => '/\A_UNSAT_\d{30}\z/' } })

        assert_empty result[:data]
        assert_match(/unsatisfiable pattern/, result[:skipped].first[:reason])
      end

      # --- numbers / boolean ---------------------------------------------------

      test 'integer number stays within its bounds' do
        value = build_value({ 'type' => 'number', 'validations' => { 'format' => 'integer', 'min' => 5, 'max' => 9 } })

        assert_kind_of Integer, value
        assert_includes 5..9, value
      end

      test 'decimal number stays within its bounds' do
        value = build_value({ 'type' => 'number', 'validations' => { 'min' => 1, 'max' => 2 } })

        assert_kind_of Float, value
        assert_includes 1.0..2.0, value
      end

      test 'boolean is true or false' do
        value = build_value({ 'type' => 'boolean' })

        assert_includes [true, false], value
      end

      # --- date / datetime / geographic ---------------------------------------

      test 'date is an iso8601 date on or after the min validation' do
        value = build_value({ 'type' => 'date', 'validations' => { 'min' => '2030-06-01' } })

        assert_operator Date.iso8601(value), :>=, Date.new(2030, 6, 1)
      end

      test 'datetime is on or after the min validation' do
        value = build_value({ 'type' => 'datetime', 'validations' => { 'min' => '2030-06-01' } })

        assert_operator Time.zone.parse(value), :>=, Time.zone.parse('2030-06-01')
      end

      test 'geographic without a subtype is a WKT point' do
        value = build_value({ 'type' => 'geographic' })

        assert_match(/\APOINT \(\d{1,2}\.\d+ \d{1,2}\.\d+\)\z/, value)
      end

      test 'geographic produces valid WKT for the subtype in ui.edit.type' do
        factory = RGeo::Geographic.simple_mercator_factory(uses_lenient_assertions: true, srid: 4326)

        ['Point', 'LineString', 'Polygon', 'MultiPoint', 'MultiLineString', 'MultiPolygon'].each do |subtype|
          value = build_value({ 'type' => 'geographic', 'ui' => { 'edit' => { 'type' => subtype } } })

          assert_equal subtype, factory.parse_wkt(value).geometry_type.type_name, value
        end
      end

      # --- schedule / table ----------------------------------------------------

      test 'schedule has a start, end and duration with the end after the start' do
        entry = build_value({ 'type' => 'schedule' }).first

        assert_equal 7200, entry['duration']
        assert_operator Time.zone.parse(entry['end_time']['time']), :>, Time.zone.parse(entry['start_time']['time'])
      end

      test 'opening_time is built like a schedule' do
        value = build_value({ 'type' => 'opening_time' })

        assert_equal 7200, value.first['duration']
      end

      test 'table rows all have the same number of columns' do
        value = build_value({ 'type' => 'table' })

        assert_operator value.size, :>=, 2
        assert_equal [2], value.map(&:size).uniq
      end

      # --- object (daterange ordering) -----------------------------------------

      test 'object orders a daterange so from is never after to' do
        definition = {
          'type' => 'object',
          'properties' => { 'date_from' => { 'type' => 'date' }, 'date_to' => { 'type' => 'date' } },
          'validations' => { 'daterange' => { 'from' => 'date_from', 'to' => 'date_to' } }
        }

        # The two dates are generated independently, so loop to make a stray ordering improbable.
        25.times do
          value = build_value(definition)

          assert_operator Date.iso8601(value['date_from']), :<=, Date.iso8601(value['date_to'])
        end
      end

      # --- embedded ------------------------------------------------------------

      test 'embedded recurses into the sub-template' do
        template = struct_double(property_definitions: { 'sub_title' => { 'type' => 'string' } })

        DataCycleCore::DataHashService.stub(:get_internal_template, template) do
          value = build_value({ 'type' => 'embedded', 'template_name' => 'SubTemplate' })

          assert_kind_of Array, value
          assert_kind_of String, value.first['sub_title']
          assert_not value.first.key?('template_name')
        end
      end

      test 'polymorphic embedded records the chosen template_name' do
        template = struct_double(property_definitions: { 'sub_title' => { 'type' => 'string' } })

        DataCycleCore::DataHashService.stub(:get_internal_template, template) do
          value = build_value({ 'type' => 'embedded', 'template_name' => ['SubA', 'SubB'] })

          assert_equal 'SubA', value.first['template_name']
        end
      end

      test 'embedded is skipped once max depth is reached' do
        result = build_result({ 'type' => 'embedded', 'template_name' => 'SubTemplate' }, max_depth: 0)

        assert_empty result[:data]
        assert_match(/max depth/, result[:skipped].first[:reason])
      end

      test 'embedded without a template_name is skipped' do
        result = build_result({ 'type' => 'embedded' })

        assert_match(/no template_name/, result[:skipped].first[:reason])
      end

      # --- classification ------------------------------------------------------

      test 'classification samples ids respecting the min/max count' do
        ids = ['c1', 'c2', 'c3', 'c4']

        DataCycleCore::Concept.stub(:for_tree, FakeRelation.new(ids)) do
          value = build_value({ 'type' => 'classification', 'tree_label' => 'SomeTree', 'validations' => { 'min' => 2, 'max' => 3 } })

          assert_equal 2, value.size
          assert(value.all? { |id| ids.include?(id) })
        end
      end

      test 'classification with an empty tree is skipped' do
        DataCycleCore::Concept.stub(:for_tree, FakeRelation.new([])) do
          result = build_result({ 'type' => 'classification', 'tree_label' => 'EmptyTree' })

          assert_empty result[:data]
          assert_match(/empty tree 'EmptyTree'/, result[:skipped].first[:reason])
        end
      end

      # --- asset ---------------------------------------------------------------

      test 'asset uses the id provided by the asset source' do
        value = build_value({ 'type' => 'asset', 'asset_type' => 'image' }, asset_source: FakeAssetSource.new('image' => 'image-1'))

        assert_equal 'image-1', value
      end

      test 'asset is skipped when the asset source provides nothing' do
        result = build_result({ 'type' => 'asset', 'asset_type' => 'video' }, asset_source: FakeAssetSource.new)

        assert_empty result[:data]
        assert_match(/no video asset available/, result[:skipped].first[:reason])
      end

      # --- linked --------------------------------------------------------------

      test 'linked excludes the current content id (no self-links)' do
        DataCycleCore::Thing.stub(:where, FakeRelation.new(['keep1', 'keep2', 'self'])) do
          value = build_value({ 'type' => 'linked', 'template_name' => 'Foo', 'validations' => { 'min' => 2 } }, exclude_id: 'self')

          assert_equal ['keep1', 'keep2'], value
        end
      end

      test 'linked with no candidate contents is skipped' do
        DataCycleCore::Thing.stub(:where, FakeRelation.new([])) do
          result = build_result({ 'type' => 'linked', 'template_name' => 'Foo' })

          assert_empty result[:data]
          assert_match(/no candidate contents/, result[:skipped].first[:reason])
        end
      end

      test 'linked is skipped when linking is disabled' do
        result = build_result({ 'type' => 'linked' }, include_linked: false)

        assert_match(/linking disabled/, result[:skipped].first[:reason])
      end

      # --- non-fillable attributes ---------------------------------------------

      test 'overlay-derived attributes (_override/_add/_overlay) are not written' do
        result = ValueBuilder.new.call({
          'name' => { 'type' => 'string' },
          'name_override' => { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } },
          'name_add' => { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }
        })

        assert_equal ['name'], result[:data].keys
        assert_empty result[:skipped]
      end

      test 'attributes disabled for editing are not written' do
        result = ValueBuilder.new.call({
          'name' => { 'type' => 'string' },
          'date_created' => { 'type' => 'datetime', 'ui' => { 'edit' => { 'disabled' => true } } }
        })

        assert_equal ['name'], result[:data].keys
        assert_empty result[:skipped]
      end

      private

      # Builds a single property value via ValueBuilder (nil when the property is skipped).
      def build_value(definition, exclude_id: nil, **builder_options)
        build_result(definition, exclude_id:, **builder_options)[:data]['field']
      end

      # Returns the full { data:, skipped: } result for a single crafted property definition.
      def build_result(definition, exclude_id: nil, **builder_options)
        ValueBuilder.new(**builder_options).call({ 'field' => definition }, exclude_id:)
      end
    end
  end
end
