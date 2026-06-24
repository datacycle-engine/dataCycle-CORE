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

          def create_unconfirmed_user
            DataCycleCore::User.create(DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
              email: "dc11_#{SecureRandom.hex(4)}@datacycle.at",
              role_id: DataCycleCore::Role.find_by(rank: 5)&.id
            }))
          end

          test 'POST /api/v4/users/resend_confirmation - allowed forwardToUrl is used in the mail link (DC-11)' do
            user = create_unconfirmed_user
            ActionMailer::Base.deliveries.clear

            post api_v4_users_resend_confirmation_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              email: user.email,
              forwardToUrl: 'https://app.dummy.com/confirm'
            }

            assert_response :success

            mail = ActionMailer::Base.deliveries.last

            assert_not_nil mail
            assert_includes (mail.html_part || mail).body.decoded, 'https://app.dummy.com/confirm'
          end

          test 'POST /api/v4/users/resend_confirmation - disallowed forwardToUrl falls back to first-party link (DC-11)' do
            user = create_unconfirmed_user
            ActionMailer::Base.deliveries.clear

            post api_v4_users_resend_confirmation_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              email: user.email,
              forwardToUrl: 'https://evil.com/capture'
            }

            assert_response :success

            mail = ActionMailer::Base.deliveries.last

            assert_not_nil mail
            body = (mail.html_part || mail).body.decoded

            assert_not_includes body, 'evil.com'
            assert_includes body, 'localhost:3000'
          end

          test 'PATCH /api/v4/users/confirm - confirm user - missing token' do
            patch api_v4_users_confirm_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {}

            assert_response :unprocessable_entity

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data.dig('errors', 'confirmation_token'), :present?
          end

          test 'PATCH /api/v4/users/confirm - confirm user - wrong token' do
            patch api_v4_users_confirm_path, headers: {
              Authorization: "Bearer #{@current_user.access_token}"
            }, params: {
              confirmationToken: 'wrongtoken'
            }

            assert_response :unprocessable_entity

            assert_includes response.content_type, 'application/json'
            json_data = response.parsed_body

            assert_predicate json_data.dig('errors', 'confirmation_token'), :present?
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
