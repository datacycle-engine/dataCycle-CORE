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
        end
      end
    end
  end
end
