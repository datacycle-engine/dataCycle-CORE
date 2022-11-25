# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      class RoutingTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.where(template: false).delete_all
          @test_content = DataCycleCore::DummyDataHelper.create_data('tour')
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/api/v3/contents/search default results' do
          get api_v3_contents_search_path
          count = DataCycleCore::Filter::Search.new.count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/contents/search with available API params' do
          get api_v3_contents_search_path
          count = DataCycleCore::Filter::Search.new.count

          included_params = DataCycleCore::Api::V3::ContentsController::ALLOWED_INCLUDE_PARAMETERS
          included_params.each do |param|
            get api_v3_contents_search_path(include: param)
            assert_response :success
            assert_equal response.content_type, 'application/json; charset=utf-8'
            json_data = JSON.parse response.body
            assert_equal count, json_data['data'].length
            assert_equal count, json_data['meta']['total'].to_i
            assert_equal true, json_data['links'].present?
          end

          mode_params = DataCycleCore::Api::V3::ContentsController::ALLOWED_MODE_PARAMETERS
          mode_params.each do |param|
            get api_v3_contents_search_path(mode: param)
            assert_response :success
            assert_equal response.content_type, 'application/json; charset=utf-8'
            json_data = JSON.parse response.body
            assert_equal count, json_data['data'].length
            assert_equal count, json_data['meta']['total'].to_i
            assert_equal true, json_data['links'].present?
          end
        end

        test '/api/v3/contents/deleted w/o any results' do
          get api_v3_contents_deleted_path

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal 0, json_data['data'].length
          assert_equal 0, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/creative_works' do
          get api_v3_creative_works_path
          count = DataCycleCore::Filter::Search.new.schema_type('CreativeWork').count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/places' do
          get api_v3_places_path
          count = DataCycleCore::Filter::Search.new.schema_type('Place').count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/events' do
          get api_v3_events_path
          count = DataCycleCore::Filter::Search.new.schema_type('Event').count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/persons' do
          get api_v3_persons_path
          count = DataCycleCore::Filter::Search.new.schema_type('Person').count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/organizations' do
          get api_v3_organizations_path
          count = DataCycleCore::Filter::Search.new.schema_type('Organization').count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end

        test '/api/v3/classification_trees' do
          params = {
            page: {
              size: 100
            }
          }
          get api_v3_classification_trees_path(params)

          count = DataCycleCore::ClassificationTreeLabel.where("ARRAY['api']::VARCHAR[] && visibility").count

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal count, json_data['data'].length
          assert_equal count, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?

          test_classification = json_data['data'].detect { |a| a['name'] == 'Tags' }['id']

          get api_v3_classification_tree_path(id: test_classification)
          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal test_classification, json_data['data']['id']

          get classifications_api_v3_classification_tree_path(id: test_classification)
          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal true, json_data['meta']['total'].positive?
        end
      end
    end
  end
end
