# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # Coverage for the dynamically defined geographic attribute writer built by
      # GeographicAttributes#define_geo_attribute_for (the `<geo_prop>=` setter).
      class GeographicAttributesSetterCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          poi = DataCycleCore::TestPreparations.create_content(
            template_name: 'POI',
            data_hash: { 'name' => 'Geo Setter Coverage POI' }
          )
          @poi_id = poi.id
        end

        # A clean, DB-backed POI without any geometry; every test mutates it in
        # memory only (rolled back per test), so all geometries stay in our factory.
        def fresh_poi
          DataCycleCore::Thing.find(@poi_id)
        end

        def point(lon, lat, alt = 100.0)
          @factory.point(lon, lat, alt)
        end

        def location_records(thing)
          thing.geometries.select { |g| g.relation == 'location' }
        end

        test 'assigning a geometry without an existing record builds a new geometry' do
          poi = fresh_poi

          assert_nil(poi.location)

          poi.location = point(11.0, 46.0)

          records = location_records(poi)

          assert_equal(1, records.size)
          assert_equal(point(11.0, 46.0), records.first.geom)
          assert_operator(records.first.priority, :>=, 1)
          assert_equal(point(11.0, 46.0), poi.location)
        end

        test 'assigning a different geometry updates the existing (unsaved) record' do
          poi = fresh_poi
          poi.location = point(11.0, 46.0)
          built = location_records(poi).first

          poi.location = point(12.0, 47.0)

          records = location_records(poi)

          assert_equal(1, records.size, 'must reuse the existing record, not build a second')
          assert_same(built, records.first)
          assert_equal(point(12.0, 47.0), records.first.geom)
          assert_not(records.first.marked_for_destruction?)
        end

        test 'assigning the same geometry twice is a no-op (early return)' do
          poi = fresh_poi
          poi.location = point(11.0, 46.0)
          built = location_records(poi).first
          geom_before = built.geom

          poi.location = point(11.0, 46.0)

          records = location_records(poi)

          assert_equal(1, records.size)
          assert_same(built, records.first)
          assert_equal(geom_before, records.first.geom)
        end

        test 'assigning a blank geometry marks the existing record for destruction' do
          poi = fresh_poi
          poi.location = point(11.0, 46.0)
          built = location_records(poi).first

          assert_not(built.marked_for_destruction?)

          poi.location = nil

          assert_predicate(built, :marked_for_destruction?)
        end
      end
    end
  end
end
