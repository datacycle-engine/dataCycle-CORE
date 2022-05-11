# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module UserApi
        class ConfirmationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @routes = Engine.routes
            @current_user = User.find_by(email: 'tester@datacycle.at')
            @current_user.update_column(:access_token, SecureRandom.hex)
            @new_user = DataCycleCore::User.create(DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
              email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
              role_id: DataCycleCore::Role.find_by(rank: 5)&.id
            }))
          end

          test 'POST /api/v4/users/resend_confirmation - send new confirmation link' do
            post api_v4_users_resend_confirmation_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              email: @new_user.email
            }

            assert_response :success
          end

          test 'PATCH /api/v4/users/confirm - confirm user - missing token' do
            patch api_v4_users_confirm_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {}

            assert_response :unprocessable_entity

            assert response.content_type.include?('application/json')
            json_data = JSON.parse(response.body)
            assert json_data.dig('errors', 'confirmation_token').present?
          end

          test 'PATCH /api/v4/users/confirm - confirm user - wrong token' do
            patch api_v4_users_confirm_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              confirmationToken: 'wrongtoken'
            }

            assert_response :unprocessable_entity

            assert response.content_type.include?('application/json')
            json_data = JSON.parse(response.body)
            assert json_data.dig('errors', 'confirmation_token').present?
          end

          test 'PATCH /api/v4/users/confirm - confirm user - ok' do
            patch api_v4_users_confirm_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              confirmationToken: @new_user.confirmation_token
            }

            assert_response :success
          end

          test 'PUT /api/v4/users/confirm - confirm user - ok' do
            put api_v4_users_confirm_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              confirmationToken: @new_user.confirmation_token
            }

            assert_response :success
          end
        end
      end
    end
  end
end
