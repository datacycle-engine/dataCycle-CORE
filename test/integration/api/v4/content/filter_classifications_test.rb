# frozen_string_literal: true

require 'test_helper'
require 'json'
# require 'v4/validation/concept'
require 'v4/helpers/dummy_data_helper'
require 'v4/helpers/api_helper'

module DataCycleCore
  module Api
    module V4
      class FilterClassificationsTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::V4::ApiHelper
        include DataCycleCore::V4::DummyDataHelper

        # setup description
        # 2 poi's: licenses: (CC BY 4.0, CC BY-SA 4.0) | CC BY (only for without subTree test)
        # 2 food_establishment CC BY 4.0 | CC BY-SA 4.0
        # 4 images CC0 | CC0 | CC0 | CC0
        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes

          @cc_by40 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY 4.0').first
          @cc_by = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY').first
          @cc_by_sa40 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY-SA 4.0').first
          @cc0 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC0').first

          @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
          license_classification = @poi_a.get_data_hash
          license_classification['license_classification'] = [@cc_by40.primary_classification.id, @cc_by_sa40.primary_classification.id]
          @poi_a.set_data_hash(prevent_history: true, data_hash: license_classification)

          @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
          license_classification = @poi_b.get_data_hash
          license_classification['license_classification'] = [@cc_by.primary_classification.id]
          @poi_b.set_data_hash(prevent_history: true, data_hash: license_classification)

          @food_establishment_a = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
          license_classification = @food_establishment_a.get_data_hash
          license_classification['license_classification'] = [@cc_by40.primary_classification.id]
          @food_establishment_a.set_data_hash(prevent_history: true, data_hash: license_classification)

          @food_establishment_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
          license_classification = @food_establishment_b.get_data_hash
          license_classification['license_classification'] = [@cc_by_sa40.primary_classification.id]
          @food_establishment_b.set_data_hash(prevent_history: true, data_hash: license_classification)

          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api/v4/things with filter[classifications][in]' do
          # all items (8)
          post_params = {}
          post api_v4_things_path(post_params)
          assert_api_count_result(8)

          # withSubtree CC BY-SA 4.0 (2)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    @cc_by_sa40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(2)

          # withSubtree CC BY 4.0 (2)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    @cc_by40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(2)

          # withSubtree CC BY (3)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(3)

          # withSubtree CC0 (4)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    @cc0.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          # withSubtree place (4)
          place = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Ort').first
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    place.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          ### Logical AND
          # withSubtree CC0 AND CC BY(0)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    @cc0.id,
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(0)

          # withSubtree food establisment AND CC BY(1)
          food_establishment = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Gastronomischer Betrieb').first
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    food_establishment.id,
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(1)

          ### Logical OR
          # withSubtree CC0 OR CC BY(7)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    "#{@cc0.id},#{@cc_by.id}"
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(7)

          # withSubtree food establisment OR CC BY(4)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    "#{food_establishment.id},#{@cc_by.id}"
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          ### withoutSubtree
          # withoutSubtree place (0)
          place = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Ort').first
          post_params = {
            filter: {
              classifications: {
                in: {
                  withoutSubtree: [
                    place.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(0)

          # withoutSubtree CC BY 4.0 (2)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withoutSubtree: [
                    @cc_by40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(2)

          # withoutSubtree CC BY (1)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withoutSubtree: [
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(1)

          # combine withSubtree and withoutSubtree
          # combine withSubtree (place) and withoutSubtree CC BY-SA 4.0 (2)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    place.id
                  ],
                  withoutSubtree: [
                    @cc_by_sa40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(2)

          # combine withSubtree (CC BY) and withoutSubtree CC BY-SA 4.0 (1)
          post_params = {
            filter: {
              classifications: {
                in: {
                  withSubtree: [
                    @cc_by.id
                  ],
                  withoutSubtree: [
                    @cc_by_sa40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(1)
        end

        test 'api/v4/things with filter[classifications][notIn]' do
          # all items (8)
          post_params = {}
          post api_v4_things_path(post_params)
          assert_api_count_result(8)

          # withSubtree CC BY-SA 4.0 (6)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    @cc_by_sa40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(6)

          # withSubtree CC BY 4.0 (6)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    @cc_by40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(6)

          # withSubtree CC BY (5)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(5)

          # withSubtree CC0 (4)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    @cc0.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          # withSubtree place (4)
          place = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Ort').first
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    place.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          ### Logical AND
          # withSubtree CC0 AND CC BY(1)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    @cc0.id,
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(1)

          # withSubtree food establisment AND CC BY(4)
          food_establishment = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Gastronomischer Betrieb').first
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    food_establishment.id,
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          ### Logical OR
          # withSubtree CC0 OR CC BY(1)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    "#{@cc0.id},#{@cc_by.id}"
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(1)

          # withSubtree food establisment OR CC BY(4)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    "#{food_establishment.id},#{@cc_by.id}"
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          ### withoutSubtree
          # withoutSubtree place (8)
          place = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Ort').first
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withoutSubtree: [
                    place.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(8)

          # withoutSubtree CC BY 4.0 (6)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withoutSubtree: [
                    @cc_by40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(6)

          # withoutSubtree CC BY (7)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withoutSubtree: [
                    @cc_by.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(7)

          # combine withSubtree and withoutSubtree
          # combine withSubtree (place) and withoutSubtree CC BY-SA 4.0 (4)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    place.id
                  ],
                  withoutSubtree: [
                    @cc_by_sa40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)

          # combine withSubtree (CC BY) and withoutSubtree CC BY-SA 4.0 (4)
          post_params = {
            filter: {
              classifications: {
                notIn: {
                  withSubtree: [
                    @cc_by.id
                  ],
                  withoutSubtree: [
                    @cc_by_sa40.id
                  ]
                }
              }
            }
          }
          post api_v4_things_path(post_params)
          assert_api_count_result(4)
        end
      end
    end
  end
end
