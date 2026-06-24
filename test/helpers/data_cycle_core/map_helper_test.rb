# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class MapHelperTest < ActionView::TestCase
    include DataCycleCore::MapHelper
    include DataCycleCore::UiLocaleHelper

    def point
      RGeo::Geographic.spherical_factory(srid: 4326).point(11.0, 46.0)
    end

    test 'value_to_geojson is nil for a blank value' do
      assert_nil value_to_geojson(nil)
      assert_nil value_to_geojson('')
    end

    test 'value_to_geojson encodes a geometry as a GeoJSON feature' do
      feature = value_to_geojson(point, { name: 'Place' })

      assert_equal 'Feature', feature[:type]
      assert_equal 'Point', feature[:geometry]['type']
      assert_equal({ name: 'Place' }, feature[:properties])
    end

    test 'value_to_geojson drops blank properties' do
      feature = value_to_geojson(point, { name: '' })

      assert_not feature.key?(:properties)
    end

    test 'geojson_properties builds the feature properties for a content' do
      content = struct_double(id: 'uuid-1', first_available_locale: :de, title: 'Hello')

      assert_equal({ '@id': 'uuid-1', name: 'Hello', clickable: true }, geojson_properties(content, { 'title' => 'title' }))
    end

    test 'classification_polygon_properties maps the polygon and its alias' do
      polygon = struct_double(id: 'p1', classification_alias: struct_double(id: 'ca1', internal_name: 'Region'))

      assert_equal({ '@id': 'p1', classificationId: 'ca1', name: 'Region' }, classification_polygon_properties(polygon))
    end

    test 'additional_map_values returns the accumulator when paths or contents are blank' do
      assert_equal({}, additional_map_values([], {}))
      assert_equal({}, additional_map_values(nil, { 'geo' => 'location' }))
    end

    test 'additional_map_values_filter is empty for blank or unknown filters' do
      assert_equal({}, additional_map_values_filter(nil))
      assert_equal({}, additional_map_values_filter({ 'made_up' => 'x' }))
    end

    test 'additional_map_values_filter builds a config for known filters' do
      result = additional_map_values_filter({ 'geo_radius' => 'distance' })

      assert result.key?('geo_radius')
      assert_predicate result['geo_radius'][:label], :present?
    end

    test 'add_map_value_filter_groups! attaches filter groups to each value' do
      values = { 'k' => { 'definition' => { 'ui' => { 'edit' => { 'filters' => {} } } } } }

      add_map_value_filter_groups!(values)

      assert_equal({}, values['k'][:filter_groups])
    end

    test 'map_filter_layers returns empty layers without geo filters' do
      assert_equal [{}, nil], map_filter_layers([])
    end

    test 'map_filter_layers collects geo_radius filter values' do
      filters = [{ 'q' => 'geo_radius', 't' => 'geo_filter', 'v' => [5] }]

      assert_equal [{ 'geo_radius' => [5] }, nil], map_filter_layers(filters)
    end
  end
end
