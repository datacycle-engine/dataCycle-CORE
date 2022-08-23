# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GeoWithGeometryTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.where(template: false).delete_all

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_a = {
              'latitude': 1,
              'longitude': 10
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)
            @poi_a.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_a.longitude, @poi_a.latitude)
            @poi_a.save

            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_b = {
              'latitude': 5,
              'longitude': 5
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)
            @poi_b.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_b.longitude, @poi_b.latitude)
            @poi_b.save

            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_c = {
              'latitude': 10,
              'longitude': 1
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)
            @poi_c.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_c.longitude, @poi_c.latitude)
            @poi_c.save

            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_d = {}
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)

            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').count
          end

          test 'api/v4/things parameter filter[:geo] with or without geometry' do
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  withGeometry: 'true'
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(3)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  withGeometry: 'false'
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)
          end
        end
      end
    end
  end
end
