# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/helpers/dummy_data_helper'
require 'v4/helpers/api_helper'

module DataCycleCore
  module Api
    module V4
      module Filter
        class TimestampsTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers
          include DataCycleCore::V4::ApiHelper
          include DataCycleCore::V4::DummyDataHelper
          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @food_establishment_a = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            @food_establishment_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')

            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').count
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things parameter filter[:createdAt]' do
            orig_ts = @food_establishment_a.created_at
            @food_establishment_a.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations

            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  createdAt: {
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
                  createdAt: {
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

            @food_establishment_a.update_column(:created_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  createdAt: {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  createdAt: {
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
                  createdAt: {
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

            @food_establishment_a.update_column(:created_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  createdAt: {
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

            @food_establishment_a.update_column(:created_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/things parameter filter[:modifiedAt]' do
            orig_ts = @food_establishment_a.updated_at
            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations

            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  modifiedAt: {
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
                  modifiedAt: {
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

            @food_establishment_a.update_column(:updated_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  modifiedAt: {
                    in: {
                      max: (Time.zone.now - 5.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  modifiedAt: {
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
                  modifiedAt: {
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

            @food_establishment_a.update_column(:updated_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  modifiedAt: {
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

            @food_establishment_a.update_column(:updated_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/things parameter filter[:modifiedAt] + filter[:createdAt]' do
            orig_ts = @food_establishment_a.updated_at
            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations

            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              fields: 'dct:modified',
              filter: {
                attribute: {
                  modifiedAt: {
                    in: {
                      min: (Time.zone.now + 5.days).to_s(:iso8601)
                    }
                  },
                  createdAt: {
                    in: {
                      max: (Time.zone.now + 1.day).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            @food_establishment_a.update_column(:updated_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end
        end
      end
    end
  end
end
