# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Extensions
      # Coverage for the Geojson concern: geojson_geometry branch matrix,
      # geojson_properties, the cached instance as_geojson and the class-level
      # feature-collection encoder. The instance methods run over a lightweight
      # named host (named so geojson_cache_key's class.name.underscore resolves);
      # the class method runs over an empty Thing relation, no fixtures needed.
      class GeojsonCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        class GeojsonHost
          include DataCycleCore::Content::Extensions::Geojson

          attr_reader :id, :title, :line, :location, :updated_at, :cache_valid_since

          def initialize(id: 'geo-1', title: 'Geo Thing', line: nil, location: nil)
            @id = id
            @title = title
            @line = line
            @location = location
            @updated_at = Time.zone.at(1_700_000_000)
            @cache_valid_since = Time.zone.at(1_700_000_000)
          end
        end

        def factory
          @factory ||= RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
        end

        def point
          factory.point(11.4, 47.3)
        end

        def line
          factory.line_string([factory.point(11.0, 47.0), factory.point(11.5, 47.5)])
        end

        test 'geojson_geometry combines line and location into a collection' do
          geom = GeojsonHost.new(line:, location: point).geojson_geometry

          assert_kind_of(RGeo::Feature::GeometryCollection, geom)
        end

        test 'geojson_geometry returns the line when no location is present' do
          l = line

          assert_equal(l, GeojsonHost.new(line: l).geojson_geometry)
        end

        test 'geojson_geometry returns the location when no line is present' do
          pt = point

          assert_equal(pt, GeojsonHost.new(location: pt).geojson_geometry)
        end

        test 'geojson_geometry returns nil without any geometry' do
          assert_nil(GeojsonHost.new.geojson_geometry)
        end

        test 'geojson_properties exposes the id and the title as name' do
          assert_equal({ id: 'geo-1', name: 'Geo Thing' }, GeojsonHost.new.geojson_properties)
        end

        test 'as_geojson builds and caches a GeoJSON feature' do
          result = GeojsonHost.new(location: point).as_geojson

          assert_equal('Feature', result['type'])
          assert_predicate(result['geometry'], :present?)
        end

        test 'class as_geojson encodes a feature collection' do
          result = DataCycleCore::Thing.where(id: nil).as_geojson

          assert_equal('FeatureCollection', result['type'])
          assert_equal([], result['features'])
        end
      end
    end
  end
end
