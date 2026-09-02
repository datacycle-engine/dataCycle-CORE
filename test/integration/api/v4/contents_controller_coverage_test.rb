# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      # Coverage for the cheap, non-render-heavy branches of Api::V4::ContentsController
      # (the index/show happy paths are covered by test/integration/api/v4/content/*).
      class ContentsControllerCoverageTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        include DataCycleCore::ApiV4Helper

        before(:all) do
          DataCycleCore::Thing.delete_all
          @routes = Engine.routes
          @user = User.find_by(email: 'tester@datacycle.at')
          DataCycleCore::DummyDataHelper.create_data('poi')
          @endpoint = DataCycleCore::StoredFilter.create!(name: 'api endpoint', user: @user, language: ['de'], api: true)
          @external_source_id = DataCycleCore::ExternalSystem.first.id
          @poi = DataCycleCore::Thing.where.not(content_type: 'embedded').first
        end

        setup do
          sign_in(@user)
        end

        test 'index in geojson format 404s when the geojson serializer is disabled' do
          post api_v4_things_path(format: :geojson)

          assert_response :not_found
        end

        test 'select without ids responds bad_request' do
          get api_v4_contents_select_path

          assert_response :bad_request
          assert_equal 'No ids given!', response.parsed_body['error']
        end

        test 'select_by_external_keys without keys responds bad_request' do
          get api_v4_things_select_by_external_key_path(external_source_id: @external_source_id)

          assert_response :bad_request
          assert_equal 'No ids given!', response.parsed_body['error']
        end

        test 'typeahead returns a suggest graph' do
          get api_v4_typeahead_path(id: @endpoint.id, search: 'a')

          assert_response :success
          assert_equal 'dcls:Statistics', response.parsed_body.dig('@graph', '@type')
          assert response.parsed_body.dig('@graph', 'suggest').is_a?(::Array)
        end

        test 'typeahead_by_title returns a suggest graph' do
          get api_v4_typeahead_by_title_path(id: @endpoint.id, search: 'a')

          assert_response :success
          assert_equal 'dcls:Statistics', response.parsed_body.dig('@graph', '@type')
        end

        test 'timeseries json responds bad_request for a content without that series' do
          get api_v4_thing_timeseries_path(id: @poi.id, timeseries: 'no_such_series', format: 'json')

          assert_response :bad_request
          assert_predicate response.parsed_body['error'], :present?
        end

        test 'timeseries csv responds bad_request for a content without that series' do
          get api_v4_thing_timeseries_path(id: @poi.id, timeseries: 'no_such_series', format: 'csv')

          assert_response :bad_request
          assert_includes response.body, 'error'
        end

        test 'statistics json renders for an allowed attribute' do
          get api_v4_statistics_path(id: @endpoint.id, attribute: 'dct:created', format: 'json')

          assert_response :success
        end

        test 'statistics json responds bad_request for an unknown attribute' do
          get api_v4_statistics_path(id: @endpoint.id, attribute: 'dct:bogus', format: 'json')

          assert_response :bad_request
          assert_predicate response.parsed_body['error'], :present?
        end

        test 'statistics csv renders for an allowed attribute' do
          get api_v4_statistics_path(id: @endpoint.id, attribute: 'dct:created', format: 'csv')

          assert_response :success
          assert_equal 'text/csv', response.media_type
        end

        test 'statistics csv responds bad_request for an unknown attribute' do
          get api_v4_statistics_path(id: @endpoint.id, attribute: 'dct:bogus', format: 'csv')

          assert_response :bad_request
        end

        test 'elevation_profile 404s for content without line geometry' do
          get api_v4_content_elevation_profile_path(id: @endpoint.id, content_id: @poi.id)

          assert_response :not_found
          assert_predicate response.parsed_body['error'], :present?
        end
      end
    end
  end
end
