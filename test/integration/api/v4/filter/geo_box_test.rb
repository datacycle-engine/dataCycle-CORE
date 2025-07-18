# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GeoBoxTest < DataCycleCore::V4::Base
          # long lat
          # 10 1
          # 5 5
          # 1 10
          # 1 1
          before(:all) do
            DataCycleCore::Thing.delete_all

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_a = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(10, 1)
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)

            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_b = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(5, 5)
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)

            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_c = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(1, 10)
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)

            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long_d = {
              location: RGeo::Geographic.spherical_factory(srid: 4326).point(1, 1)
            }
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          # sw_lon, sw_lat, ne_lon, ne_lat
          test 'api/v4/things parameter filter[:geo]' do
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
                    box: ['1', '3', '7', '12']
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
                    box: ['2', '1', '7', '6']
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
                  in: {
                    box: ['-1', '-1', '11', '12']
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
                    box: ['10', '2', '13', '15']
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
                  in: {
                    box: ['0.5', '0.5', '12', '4']
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            # notIn
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  notIn: {
                    box: ['1', '3', '7', '12']
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
                    box: ['2', '1', '7', '6']
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(3)

            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  notIn: {
                    box: ['-1', '-1', '11', '12']
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
                    box: ['10', '2', '13', '15']
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
                  notIn: {
                    box: ['0.5', '0.5', '12', '4']
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            # combine in and notIn
            params = {
              fields: 'dct:modified,geo.latitude,geo.longitude',
              filter: {
                geo: {
                  in: {
                    box: ['0.5', '0.5', '12', '4']
                  },
                  notIn: {
                    box: ['1', '1', '3', '3']
                  }
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
