# frozen_string_literal: true

require 'test_helper'
require 'json'
# require 'v4/validation/concept'
require 'v4/helpers/dummy_data_helper'

module DataCycleCore
  module Api
    module V4
      class FilterClassificationsTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper
        include DataCycleCore::V4::DummyDataHelper

        # setup description
        # 2 poi's: licenses: CC BY 4.0 | CC BY (only for without subTree test)
        # 2 food_establishment CC BY 4.0 | CC BY-SA 4.0
        # 4 images CC0 | CC0 | CC0 | CC0
        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes

          cc_by40 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY 4.0').first.primary_classification.id
          cc_by = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY').first.primary_classification.id
          cc_by_sa40 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY-SA 4.0').first.primary_classification.id

          @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
          license_classification = @poi_a.get_data_hash
          license_classification['license_classification'] = [cc_by40]
          @poi_a.set_data_hash(prevent_history: true, data_hash: license_classification)

          @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
          license_classification = @poi_b.get_data_hash
          license_classification['license_classification'] = [cc_by]
          @poi_b.set_data_hash(prevent_history: true, data_hash: license_classification)

          @food_establishment_a = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
          license_classification = @food_establishment_a.get_data_hash
          license_classification['license_classification'] = [cc_by40]
          @food_establishment_a.set_data_hash(prevent_history: true, data_hash: license_classification)

          @food_establishment_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
          license_classification = @food_establishment_b.get_data_hash
          license_classification['license_classification'] = [cc_by_sa40]
          @food_establishment_b.set_data_hash(prevent_history: true, data_hash: license_classification)

          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api/v4/things get all available items' do
          post_params = {}
          post api_v4_things_path(post_params)

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)

          assert_equal(8, json_data['@graph'].size)
          assert_equal(8, json_data['meta']['total'].to_i)
        end
      end
    end
  end
end
