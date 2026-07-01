# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  module Api
    module V4
      module ExternalSystems
        class ExternalSystemsControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @routes = Engine.routes
            @external_system = DataCycleCore::ExternalSystem.first || Struct.new(:id, :identifier).new(1, 'test-external')
            @content = create_content('Timeseries', { name: 'TS Test', external_key: 'ts-test', external_source_id: @external_system.id })
            @current_user = User.find_by(email: 'tester@datacycle.at')
          end

          setup do
            sign_in(@current_user)
          end

          test 'timeseries endpoint with attribute does not forward attacker-supplied keys' do
            payload = { 'data' => [['2026-04-30T12:00:00Z', 42]], 'admin' => { 'evil' => '1' } }
            mock_method = Minitest::Mock.new
            mock_method.expect :call, {
              meta: {
                thing_id: @content.id,
                processed: {
                  inserted: 1,
                  duplicates: 0
                }
              }
            } do |_content, data|
              assert_equal 1, data.size
              assert_equal 'series', data[0][:property]
              assert_equal '2026-04-30T12:00:00Z', data[0][:timestamp]
              assert_equal 42, data[0][:value]
              assert_equal @content.id, data[0][:thing_id]
            end

            DataCycleCore::Timeseries.stub :create_all, mock_method do
              patch api_v4_external_source_timeseries_path(external_source_id: @external_system.id, external_key: @content.external_key, attribute: 'series'), params: payload, as: :json

              assert_response :accepted
            end
            mock_method.verify
          end

          test 'timeseries endpoint without attribute does not forward attacker-supplied keys' do
            payload = { 'series' => [['2026-04-30T12:00:00Z', 42]], 'admin' => { 'evil' => '1' } }
            mock_method = Minitest::Mock.new
            mock_method.expect :call, {
              meta: {
                thing_id: @content.id,
                processed: {
                  inserted: 1,
                  duplicates: 0
                }
              }
            } do |_content, data|
              assert_equal 1, data.size
              assert_equal 'series', data[0][:property]
              assert_equal '2026-04-30T12:00:00Z', data[0][:timestamp]
              assert_equal 42, data[0][:value]
              assert_equal @content.id, data[0][:thing_id]
            end

            DataCycleCore::Timeseries.stub :create_all, mock_method do
              patch api_v4_external_source_timeseries_bulk_path(external_source_id: @external_system.id, external_key: @content.external_key), params: payload, as: :json

              assert_response :accepted
            end
            mock_method.verify
          end

          # ---- timeseries guard branches ----
          test 'timeseries returns not found for an unknown external key' do
            patch api_v4_external_source_timeseries_path(external_source_id: @external_system.id, external_key: 'does-not-exist', attribute: 'series'),
                  params: { 'series' => [['2026-04-30T12:00:00Z', 42]] }, as: :json

            assert_response :not_found
          end

          test 'timeseries returns not found for an attribute the content does not have' do
            patch api_v4_external_source_timeseries_path(external_source_id: @external_system.id, external_key: @content.external_key, attribute: 'notaproperty'),
                  params: { 'notaproperty' => [['2026-04-30T12:00:00Z', 42]] }, as: :json

            assert_response :not_found
          end

          test 'timeseries returns no content when no data is supplied' do
            patch api_v4_external_source_timeseries_bulk_path(external_source_id: @external_system.id, external_key: @content.external_key),
                  params: {}, as: :json

            assert_response :no_content
          end

          # ---- content_request guard branches (create / demote) ----
          test 'create returns endpoint not active when the external system has no api strategy' do
            es = DataCycleCore::ExternalSystem.create!(name: 'Cov No Strategy', identifier: 'cov-no-strategy', config: {})

            post api_v4_path(external_source_id: es.id), params: { '@graph' => [{ 'name' => 'x' }] }, as: :json

            assert_response :not_found
            assert_equal 'endpoint not active', response.parsed_body['error']
          end

          test 'demote returns endpoint not active when the external system has no api strategy' do
            es = DataCycleCore::ExternalSystem.create!(name: 'Cov No Strategy Demote', identifier: 'cov-no-strategy-demote', config: {})

            patch api_v4_demote_path(external_source_id: es.id), params: { '@graph' => [{ 'name' => 'x' }] }, as: :json

            assert_response :not_found
          end

          test 'content request rejects an invalid locale' do
            es = DataCycleCore::ExternalSystem.find_by(identifier: 'test-system-1') # configured with an api_strategy

            post api_v4_path(external_source_id: es.id),
                 params: { '@context' => { '@language' => 'xx' }, '@graph' => [{ 'name' => 'x' }] }, as: :json

            assert_response :bad_request
          end

          # ---- feratel-only endpoints reject non-feratel / invalid input ----
          test 'search_availability is only available for feratel data' do
            es = DataCycleCore::ExternalSystem.create!(name: 'Cov Search', identifier: 'cov-search')

            get api_v4_external_source_search_availability_path(external_source_id: es.id)

            assert_response :bad_request
            assert_equal 'Only available for Feratel data.', response.parsed_body['error']
          end

          test 'search_additional_service is only available for feratel data' do
            es = DataCycleCore::ExternalSystem.create!(name: 'Cov Search AS', identifier: 'cov-search-as')

            get api_v4_external_source_search_additional_service_path(external_source_id: es.id)

            assert_response :bad_request
          end

          test 'facets_feratel_locations rejects an invalid type' do
            es = DataCycleCore::ExternalSystem.create!(name: 'Cov Facets', identifier: 'cov-facets')

            get api_v4_external_source_facets_feratel_locations_path(external_source_id: es.id, type: 'invalid')

            assert_response :bad_request
          end
        end
      end
    end
  end
end
