# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      class RoutingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/api/v2/contents/search default results' do
          get api_v2_contents_search_path
          count = DataCycleCore::Search.select(:content_data_id).distinct.limit(25).size

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v2/contents/deleted w/o any results' do
          get api_v2_contents_deleted_path

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal 0, json_data['data'].length
          assert_equal 0, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v2/creative_works default results' do
          get api_v2_creative_works_path
          count = DataCycleCore::CreativeWork.where(template: false).limit(25).size

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v2/places w/o any results' do
          get api_v2_places_path

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal 0, json_data['data'].length
          assert_equal 0, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v2/events w/o any results' do
          get api_v2_events_path

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal 0, json_data['data'].length
          assert_equal 0, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v2/persons w/o any results' do
          get api_v2_persons_path

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal 0, json_data['data'].length
          assert_equal 0, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v2/classification_trees' do
          get api_v2_classification_trees_path

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal 17, json_data['data'].length
          assert_equal 17, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?

          test_classification = json_data['data'].select { |a| a['name'] == 'Tags' }.first['id']

          get api_v2_classification_tree_path(id: test_classification)
          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal test_classification, json_data['data']['id']

          get classifications_api_v2_classification_tree_path(id: test_classification)
          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal true, json_data['meta']['total'].positive?
        end
      end
    end
  end
end
