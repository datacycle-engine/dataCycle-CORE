# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class RoutingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          @watch_list = DataCycleCore::WatchList.create({
            name: 'Merkliste 1',
            user: User.find_by(email: 'tester@datacycle.at')
          })
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/api/v4/collections default results' do
          get api_v4_collections_path

          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].length)
        end

        test '/api/v4/collections/:id default results' do
          get api_v4_collection_path(id: @watch_list.id)

          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal('Merkliste 1', json_data.dig('meta', 'watchList', 'name'))
          assert_equal(0, json_data.dig('meta', 'total'))
          assert_equal(0, json_data.dig('meta', 'pages'))
          assert_equal(0, json_data.dig('@graph').length)
        end

        test '/api/v4/endpoints/:id default results and /api/v4/users/' do
          post(
            stored_filters_path,
            params: { stored_filter: { name: 'TestFilter' } },
            headers: { referer: root_path }
          )
          filter = User.find_by(email: 'tester@datacycle.at').stored_filters.presence&.find_by(name: 'TestFilter')
          assert(filter.present?)
          assert_redirected_to(root_path(stored_filter: filter.id))
          follow_redirect!

          filter.update(api: true)
          get api_v4_stored_filter_path(id: filter.id)
          assert_response :success
          assert_equal(response.content_type, 'application/json')

          get api_v4_users_path
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(['@graph'], json_data.keys)
          assert_equal(@watch_list.id, json_data.dig('@graph', 'watchLists', 0, 'id'))
          assert_equal(@watch_list.name, json_data.dig('@graph', 'watchLists', 0, 'name'))
          assert_equal([], json_data.dig('@graph', 'storedFilters'))
          assert_equal('tester@datacycle.at', json_data.dig('@graph', 'userData', 'email'))
        end
      end
    end
  end
end