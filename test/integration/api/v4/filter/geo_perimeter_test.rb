# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GeoPerimeterTest < DataCycleCore::V4::Base
          # long lat
          # 10 1
          # 5 5
          # 1 10
          # 1 1
          before(:all) do
            DataCycleCore::Thing.delete_all

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_a = {
              'latitude': 1,
              'longitude': 10
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)
            @poi_a.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_a.longitude, @poi_a.latitude)
            @poi_a.save

            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_b = {
              'latitude': 5,
              'longitude': 5
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)
            @poi_b.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_b.longitude, @poi_b.latitude)
            @poi_b.save

            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_c = {
              'latitude': 10,
              'longitude': 1
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)
            @poi_c.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_c.longitude, @poi_c.latitude)
            @poi_c.save

            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_d = {
              'latitude': 1,
              'longitude': 1
            }
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)
            @poi_d.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_d.longitude, @poi_d.latitude)
            @poi_d.save

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          # sw_lon, sw_lat, ne_lon, ne_lat
          test 'api/v4/things parameter filter[:geo][:perimeter]' do
            # distance: 1 degree ~ 111km
            distance_one_degree = 111 * 1000
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (10 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (7 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (1 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  notIn: {
                    perimeter: ['1', '1', (10 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(0)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  notIn: {
                    perimeter: ['1', '1', (7 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  notIn: {
                    perimeter: ['1', '1', (1 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(3)
          end
        end
      end
    end
  end
end
