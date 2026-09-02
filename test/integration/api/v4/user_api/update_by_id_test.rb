# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module UserApi
        class UpdateByIdTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @service_user = create_api_user(rank: 5)
            @service_user.user_groups = [DataCycleCore::UserGroup.find_or_create_by!(name: 'Service Tokens')]

            @ungrouped_user = create_api_user(rank: 5)
            @guest = create_api_user(rank: 0)
            @other_standard = create_api_user(rank: 5)
          end

          test 'PATCH /api/v4/users/:id - service token updates a guest' do
            patch api_v4_users_user_path(id: @guest.id), headers: auth_headers, params: { givenName: 'Patched' }

            assert_response :ok
            assert_equal('Patched', @guest.reload.given_name)
          end

          test 'PUT /api/v4/users/:id - service token updates a guest' do
            put api_v4_users_user_path(id: @guest.id), headers: auth_headers, params: { givenName: 'Putted' }

            assert_response :ok
            assert_equal('Putted', @guest.reload.given_name)
          end

          # a token for the account just written would turn :update into a sign in as that user
          test 'PATCH /api/v4/users/:id - answers without a user token' do
            patch api_v4_users_user_path(id: @guest.id), headers: auth_headers, params: { givenName: 'Tokenless' }

            assert_response :ok

            json_data = response.parsed_body

            assert_equal(@guest.id, json_data['id'])
            assert_not(json_data.key?('token'))
            assert_not(json_data.key?('exp'))
          end

          test 'PATCH /api/v4/users/:id - denied for an api token outside the user group' do
            patch api_v4_users_user_path(id: @guest.id), headers: auth_headers(@ungrouped_user), params: { givenName: 'Denied' }

            assert_response :unauthorized
            assert_not_equal('Denied', @guest.reload.given_name)
          end

          test 'PATCH /api/v4/users/:id - denied for a target outside the role whitelist' do
            patch api_v4_users_user_path(id: @other_standard.id), headers: auth_headers, params: { givenName: 'Denied' }

            assert_response :unauthorized
            assert_not_equal('Denied', @other_standard.reload.given_name)
          end

          private

          def auth_headers(user = @service_user)
            { Authorization: "Bearer #{user.access_token}" }
          end

          def create_api_user(rank:)
            user = DataCycleCore::User.create!(
              DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
                email: "update_by_id_#{SecureRandom.hex(6)}@datacycle.at",
                confirmed_at: 1.day.ago,
                role_id: DataCycleCore::Role.find_by(rank:)&.id
              })
            )
            user.update_column(:access_token, SecureRandom.hex)
            user
          end
        end
      end
    end
  end
end
