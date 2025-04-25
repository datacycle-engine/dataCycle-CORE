# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class AdvancedAttributeFilter < DataCycleCore::V4::Base
          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          before(:all) do
            @cs_a = DataCycleCore::V4::DummyDataHelper.create_data('charging_station')
            @cs_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: {
              'title' => 'A',
              'dc_capacity' => 2,
              'amperage' => 3,
              'voltage' => 4,
              'power' => 11,
              'dc_nominal_capacity' => 15
            })
            puts @cs_a.id

            @cs_b = DataCycleCore::V4::DummyDataHelper.create_data('charging_station')
            @cs_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: {
              'title' => 'B',
              'dc_capacity' => 4,
              'amperage' => 6,
              'voltage' => 8,
              'power' => 22,
              'dc_nominal_capacity' => 30
            })
            puts @cs_b.id
            @cs_c = DataCycleCore::V4::DummyDataHelper.create_data('charging_station')
            @cs_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: {
              'title' => 'C',
              'dc_capacity' => 6,
              'amperage' => 9,
              'voltage' => 12,
              'power' => 33,
              'dc_nominal_capacity' => 45
            })
            puts @cs_c.id

            @thing_count = DataCycleCore::Thing.where.not(template_name: 'Ladestation').count
            puts @thing_count
          end

          test 'api/v4/things with filter for additional attribute' do
            post_params = {
              filter: {
                attribute: {
                  'dc:capacity': {
                    in: {
                      equals: '4'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal(@cs_b.id, json_data['@graph'].first['@id'])

            post_params = {
              filter: {
                attribute: {
                  amperage: {
                    in: {
                      equals: '6'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)
            assert_equal(@cs_b.id, json_data['@graph'].first['@id'])

            post_params = {
              filter: {
                attribute: {
                  voltage: {
                    in: {
                      equals: '8'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)
            assert_equal(@cs_b.id, json_data['@graph'].first['@id'])

            post_params = {
              filter: {
                attribute: {
                  dcPower: {
                    in: {
                      equals: '22'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)
            assert_equal(@cs_b.id, json_data['@graph'].first['@id'])

            post_params = {
              filter: {
                attribute: {
                  dcNominalCapacity: {
                    in: {
                      equals: '30'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)
            assert_equal(@cs_b.id, json_data['@graph'].first['@id'])
          end
        end
      end
    end
  end
end
