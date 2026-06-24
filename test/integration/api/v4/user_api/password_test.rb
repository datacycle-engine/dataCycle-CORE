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

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data.dig('errors', 'reset_password_token'), :present?
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

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data.dig('errors', 'reset_password_token'), :present?
          end

          test 'PATCH /api/v4/users/password - change password for user - missing password' do
            reset_token = @new_user.send(:set_reset_password_token)

            patch api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              resetPasswordToken: reset_token
            }

            assert_response :unprocessable_entity

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data.dig('errors', 'password'), :present?
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

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data['token'], :present?
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

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data['token'], :present?
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

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data['token'], :present?
          end

          test 'POST /api/v4/users/password - allowed forwardToUrl is used in the reset mail link (DC-11)' do
            ActionMailer::Base.deliveries.clear

            post api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              email: @new_user.email,
              forwardToUrl: 'https://app.dummy.com/reset'
            }

            assert_response :success

            mail = ActionMailer::Base.deliveries.last

            assert_not_nil mail
            assert_includes (mail.html_part || mail).body.decoded, 'https://app.dummy.com/reset'
          end

          test 'POST /api/v4/users/password - disallowed forwardToUrl falls back to first-party link (DC-11)' do
            ActionMailer::Base.deliveries.clear

            post api_v4_users_password_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              email: @new_user.email,
              forwardToUrl: 'https://evil.com/capture'
            }

            assert_response :success

            mail = ActionMailer::Base.deliveries.last

            assert_not_nil mail
            body = (mail.html_part || mail).body.decoded

            assert_not_includes body, 'evil.com'
            # token is sent to the first-party devise edit_password url instead
            assert_includes body, 'localhost:3000'
          end
        end
      end
    end
  end
end
