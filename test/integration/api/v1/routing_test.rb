# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V1
      class RoutingTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.where(template: false).delete_all
          @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'Merkliste 1')
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/api/v1/collections default results' do
          get api_v1_collections_path

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal 1, json_data['collections'].length
        end

        test '/api/v1/collections/:id default results' do
          get api_v1_collection_path(@watch_list)

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal 'Merkliste 1', json_data.dig('collection', 'name')
          assert_equal 0, json_data.dig('collection', 'items').length
        end

        test '/api/v1/endpoints/:id default results' do
          post stored_filters_path, params: {
            stored_filter: {
              name: 'TestFilter'
<<<<<<< HEAD
            }
=======
            },
            update_filter_parameters: true
>>>>>>> old/develop
          }, headers: {
            referer: root_path
          }

          filter = User.find_by(email: 'tester@datacycle.at').stored_filters.presence&.find_by(name: 'TestFilter')
          assert filter.present?

          assert_redirected_to root_path(stored_filter: filter.id)
          follow_redirect!

          filter.update(api: true)

          get api_v1_stored_filter_path(filter)

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
        end
      end
    end
  end
end
