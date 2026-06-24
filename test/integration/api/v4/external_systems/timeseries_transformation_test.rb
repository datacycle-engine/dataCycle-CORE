# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  module Api
    module V4
      module ExternalSystems
        class TimeseriesTransformationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          MOCK_TIMESTAMP = '2026-06-11T10:00:00+02:00'

          before(:all) do
            @routes = Engine.routes
            @external_system = DataCycleCore::ExternalSystem.find_or_initialize_by(identifier: 'toewervital')
            @external_system.name = 'ToewerVital'
            @external_system.config = (@external_system.config || {}).merge(
              'transformations' => {
                'dcls_occupancy' => [
                  { 'type' => 'zero_if', 'property' => 'dcls_facility_state', 'values' => [0] }
                ]
              }
            )
            @external_system.save!
            @external_system.reset_memoized_variables!
            @content = create_content('TimeseriesTransformation', { name: 'Sauna', external_key: 'sauna-test', external_source_id: @external_system.id })
            @current_user = User.find_by(email: 'tester@datacycle.at')
          end

          setup do
            sign_in(@current_user)
          end

          test 'passes occupancy through unchanged when facility is open' do
            payload = {
              'dcls_capacity' => [MOCK_TIMESTAMP, 130],
              'dcls_facility_state' => [MOCK_TIMESTAMP, 1],
              'dcls_free_places' => [MOCK_TIMESTAMP, 124],
              'dcls_occupancy' => [MOCK_TIMESTAMP, 6]
            }

            mock_method = Minitest::Mock.new

            mock_method.expect(:call, mock_response) do |_content, data|
              assert_equal 6, data.find { |d| d[:property] == 'dcls_occupancy' }[:value]
            end

            DataCycleCore::Timeseries.stub :create_all, mock_method do
              patch api_v4_external_source_timeseries_bulk_path(external_source_id: @external_system.id, external_key: @content.external_key),
                    params: payload, as: :json

              assert_response :accepted
            end
            mock_method.verify
          end

          test 'zeros occupancy when facility is closed' do
            payload = {
              'dcls_capacity' => [MOCK_TIMESTAMP, 130],
              'dcls_facility_state' => [MOCK_TIMESTAMP, 0],
              'dcls_free_places' => [MOCK_TIMESTAMP, 0],
              'dcls_occupancy' => [MOCK_TIMESTAMP, 99]
            }

            mock_method = Minitest::Mock.new

            mock_method.expect(:call, mock_response) do |_content, data|
              assert_equal 0, data.find { |d| d[:property] == 'dcls_occupancy' }[:value]
            end

            DataCycleCore::Timeseries.stub :create_all, mock_method do
              patch api_v4_external_source_timeseries_bulk_path(external_source_id: @external_system.id, external_key: @content.external_key),
                    params: payload, as: :json

              assert_response :accepted
            end
            mock_method.verify
          end

          private

          def mock_response
            { meta: { thing_id: @content.id, processed: { inserted: 4, duplicates: 0 } } }
          end
        end
      end
    end
  end
end
