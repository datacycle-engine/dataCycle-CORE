# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GeoWithGeometryTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_a = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(10, 1)
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)

            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_b = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(5, 5)
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)

            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_c = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(1, 10)
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)

            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_d = { location: nil }
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
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
