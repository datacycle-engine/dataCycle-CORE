# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class ProximityGeographicWith < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all

            @poi_a = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => 'POI A' })
            lat_long_a = {
              latitude: 1,
              longitude: 9
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)
            @poi_a.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_a.longitude, @poi_a.latitude)
            @poi_a.save

            @poi_b = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => 'POI B' })
            lat_long_b = {
              latitude: 5,
              longitude: 5
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)
            @poi_b.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_b.longitude, @poi_b.latitude)
            @poi_b.save

            @poi_c = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => 'POI C' })
            lat_long_c = {
              latitude: 10,
              longitude: 1
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)
            @poi_c.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_c.longitude, @poi_c.latitude)
            @poi_c.save

            @poi_d = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => 'POI D' })
            lat_long_d = {
              latitude: 1,
              longitude: 1
            }
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)
            @poi_d.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_d.longitude, @poi_d.latitude)
            @poi_d.save

            # pois without location
            @poi_e = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => 'POI E' })
            @poi_f = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { 'name' => 'POI F' })

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          test 'api/v4/things with parameter sort: proximity.geographic_with' do
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            # sorting: proximity.geographic_with(LONGITUDE, LATITUDE) --> 1, 1 ASC
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              sort: 'proximity.geographic_with(1, 1)'
            }
            post api_v4_things_path(params)
            assert_api_count_result(6)

            json_data = response.parsed_body
            assert_equal([@poi_d.id, @poi_b.id, @poi_a.id, @poi_c.id, @poi_f.id, @poi_e.id], json_data['@graph'].pluck('@id'))

            # sorting: proximity.geographic_with(LONGITUDE, LATITUDE)  1, 1 DESC
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              sort: '-proximity.geographic_with(1, 1)'
            }
            post api_v4_things_path(params)
            assert_api_count_result(6)

            json_data = response.parsed_body
            assert_equal([@poi_c.id, @poi_a.id, @poi_b.id, @poi_d.id, @poi_f.id, @poi_e.id], json_data['@graph'].pluck('@id'))

            # sorting: proximity.geographic_with(LONGITUDE, LATITUDE) --> 10, 1 ASC
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              sort: 'proximity.geographic_with(10, 1)'
            }
            post api_v4_things_path(params)
            assert_api_count_result(6)

            json_data = response.parsed_body
            assert_equal([@poi_a.id, @poi_b.id, @poi_d.id, @poi_c.id, @poi_f.id, @poi_e.id], json_data['@graph'].pluck('@id'))

            # sorting: proximity.geographic_with(LONGITUDE, LATITUDE)  10, 1 DESC
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              sort: '-proximity.geographic_with(10, 1)'
            }
            post api_v4_things_path(params)
            assert_api_count_result(6)
            json_data = response.parsed_body
            assert_equal([@poi_c.id, @poi_d.id, @poi_b.id, @poi_a.id, @poi_f.id, @poi_e.id], json_data['@graph'].pluck('@id'))
          end
        end
      end
    end
  end
end
