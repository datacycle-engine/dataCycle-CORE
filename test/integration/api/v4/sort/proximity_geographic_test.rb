# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class ProximityGeographic < DataCycleCore::V4::Base
          # long lat
          # 10 1
          # 5 5
          # 1 10
          # 1 1
          before(:all) do
            DataCycleCore::Thing.delete_all

            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_d = {
              latitude: 1,
              longitude: 1,
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(1.to_f, 1.to_f)
            }
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)

            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_c = {
              latitude: 10,
              longitude: 1,
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(1.to_f, 10.to_f)
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)

            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_b = {
              latitude: 5,
              longitude: 5,
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(5.to_f, 5.to_f)
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_a = {
              latitude: 1,
              longitude: 10,
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(10.to_f, 1.to_f)
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)

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

            # default sorting: proximity.geographic ASC
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

            json_data = response.parsed_body
            assert_equal([@poi_d.id, @poi_b.id, @poi_a.id, @poi_c.id], json_data['@graph'].pluck('@id'))

            # sorting: proximity.geographic ASC
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (10 * distance_one_degree)]
                  }
                }
              },
              sort: 'proximity.geographic'
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body
            assert_equal([@poi_d.id, @poi_b.id, @poi_a.id, @poi_c.id], json_data['@graph'].pluck('@id'))

            # proximity.geographic DESC
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (10 * distance_one_degree)]
                  }
                }
              },
              sort: '-proximity.geographic'
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body
            assert_equal([@poi_a.id, @poi_c.id, @poi_b.id, @poi_d.id], json_data['@graph'].pluck('@id'))
          end
        end
      end
    end
  end
end
