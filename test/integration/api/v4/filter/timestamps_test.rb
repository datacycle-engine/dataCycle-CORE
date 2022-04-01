# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class TimestampsTest < DataCycleCore::V4::Base
          before(:all) do
            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @food_establishment_a = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            @food_establishment_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').size
          end

          test 'api/v4/things parameter filter[dct:created]' do
            orig_ts = @food_establishment_a.created_at
            @food_establishment_a.update_column(:created_at, (Time.zone.now + 10.days))

            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601),
                      max: (Time.zone.now + 12.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:created_at, (Time.zone.now - 10.days))
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:created_at, (Time.zone.now + 10.days))
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count - 1)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601),
                      max: (Time.zone.now + 12.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count - 1)

            @food_establishment_a.update_column(:created_at, (Time.zone.now - 10.days))
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    },
                    notIn: {
                      max: (Time.zone.now - 15.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:created_at, orig_ts)
          end

          test 'api/v4/things parameter filter[:dct:modified]' do
            orig_ts = @food_establishment_a.updated_at
            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days))

            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601),
                      max: (Time.zone.now + 12.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:updated_at, (Time.zone.now - 10.days))
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days))
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count - 1)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601),
                      max: (Time.zone.now + 12.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count - 1)

            @food_establishment_a.update_column(:updated_at, (Time.zone.now - 10.days))
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    },
                    notIn: {
                      max: (Time.zone.now - 15.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:updated_at, orig_ts)
          end

          test 'api/v4/things parameter filter[:dct:modified] + filter[:dct:created]' do
            orig_ts = @food_establishment_a.updated_at
            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days))

            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  },
                  'dct:created': {
                    in: {
                      max: (Time.zone.now + 1.day).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:updated_at, orig_ts)
          end

          test 'api/v4/things/deleted endpoint' do
            params = {}
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(0)

            food_establishment_a_id = @food_establishment_a.id
            food_establishment_b_id = @food_establishment_b.id

            @food_establishment_a.destroy_content
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(1)

            @food_establishment_b.destroy_content

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      min: Time.zone.now.to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(2)

            # make sure only id and deleted_at timestamp is present
            json_data = JSON.parse(response.body)
            validator = DataCycleCore::V4::Validation::Thing.deleted_thing
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end

            # make sure items ordered by deleted_at DESC
            assert_equal(food_establishment_b_id, json_data['@graph'].first.dig('@id'))
            assert_equal(food_establishment_a_id, json_data['@graph'].second.dig('@id'))

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      min: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(2)

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      max: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(2)

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(0)

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      min: (Time.zone.now - 5.days).to_s(:iso8601),
                      max: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(2)

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      min: (Time.zone.now - 5.days).to_s(:iso8601)
                    },
                    notIn: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_contents_deleted_path(params)
            assert_api_count_result(2)
          end
        end
      end
    end
  end
end
