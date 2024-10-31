# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module UserApi
        class PasswordTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @routes = Engine.routes
            @current_user = User.find_by(email: 'tester@datacycle.at')
            @current_user.update_column(:access_token, SecureRandom.hex)
            @new_user = DataCycleCore::User.create(DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
              email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
              confirmed_at: 1.day.ago,
              role_id: DataCycleCore::Role.find_by(rank: 5)&.id
            }))
          end

          test 'PATCH /api/v4/users/password - change password for user - missing token' do
            password = Devise.friendly_token

            patch api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              password:
            }

            assert_response :unprocessable_entity

            assert response.content_type.include?('application/json')
            json_data = response.parsed_body
            assert json_data.dig('errors', 'reset_password_token').present?
          end

          test 'PATCH /api/v4/users/password - change password for user - invalid token' do
            password = Devise.friendly_token

            patch api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              resetPasswordToken: 'invalid',
              password:
            }

            assert_response :unprocessable_entity

            assert response.content_type.include?('application/json')
            json_data = response.parsed_body
            assert json_data.dig('errors', 'reset_password_token').present?
          end

          test 'PATCH /api/v4/users/password - change password for user - missing password' do
            reset_token = @new_user.send(:set_reset_password_token)

            patch api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              resetPasswordToken: reset_token
            }

            assert_response :unprocessable_entity

            assert response.content_type.include?('application/json')
            json_data = response.parsed_body
            assert json_data.dig('errors', 'password').present?
          end

          test 'PATCH /api/v4/users/password - change password for user - ok with single password' do
            reset_token = @new_user.send(:set_reset_password_token)
            password = Devise.friendly_token

            patch api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              resetPasswordToken: reset_token,
              password:
            }

            assert_response :success

            assert response.content_type.include?('application/json')
            json_data = response.parsed_body
            assert json_data['token'].present?
          end

          test 'PATCH /api/v4/users/password - change password for user - ok with password and confirmation' do
            reset_token = @new_user.send(:set_reset_password_token)
            password = Devise.friendly_token

            patch api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              resetPasswordToken: reset_token,
              password:,
              passwordConfirmation: password
            }

            assert_response :success

            assert response.content_type.include?('application/json')
            json_data = response.parsed_body
            assert json_data['token'].present?
          end

          test 'PUT /api/v4/users/password - change password for user - ok with single password' do
            reset_token = @new_user.send(:set_reset_password_token)
            password = Devise.friendly_token

            put api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              resetPasswordToken: reset_token,
              password:
            }

            assert_response :success

            assert response.content_type.include?('application/json')
            json_data = response.parsed_body
            assert json_data['token'].present?
          end
        end
      end
    end
  end
end
