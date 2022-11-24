# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class JwtAuthenticationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @current_user = User.find_by(email: 'tester@datacycle.at')
          @current_user.update_column(:access_token, SecureRandom.hex)

          @user_data = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
            email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
            confirmed_at: Time.zone.now - 1.day,
            role_id: DataCycleCore::Role.find_by(rank: 2)&.id
          })
          @new_user = DataCycleCore::User.create(@user_data)
        end

        def generate_private_key
          rsa_private = OpenSSL::PKey::RSA.generate 2048
          rsa_public = rsa_private.public_key
          DataCycleCore.features[:user_api][:public_keys] = { 'datacycle.at': rsa_public.to_s }
          DataCycleCore::Feature::UserApi.reload
          rsa_private
        end

        test '/api/v4/auth/login - login without email returns 404' do
          post api_v4_authentication_login_path, params: {}, headers: {}

          assert_response 401
        end

        test '/api/v4/auth/login - login with token' do
          post api_v4_authentication_login_path, params: {
            email: @user_data[:email],
            password: @user_data[:password],
            token: @current_user.access_token
          }, headers: {}

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data.dig('user', 'email')

          new_token = json_data['token']
          post api_v4_authentication_login_path, headers: {
            Authorization: "Bearer #{new_token}"
          }, params: {
            email: @user_data[:email],
            password: @user_data[:password]
          }

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data.dig('user', 'email')
        end

        test '/api/v4/auth/login - login with JWT, signed with Secret' do
          token = DataCycleCore::JsonWebToken.encode(payload: { user_id: @current_user.id, jti: @current_user.jti }).token

          post api_v4_authentication_login_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {
            email: @user_data[:email],
            password: @user_data[:password]
          }
          assert_response :success

          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data.dig('user', 'email')
        end

        test '/api/v4/auth/login - login with token in header as Authorization Bearer -> Unauthorized' do
          get api_v4_users_path, headers: {
            Authorization: "Bearer #{@current_user.access_token}"
          }, params: {}

          assert_response :success
        end

        test '/api/v4/auth/login - login with token in header as Authorization -> Unauthorized' do
          get api_v4_users_path, headers: {
            Authorization: @current_user.access_token
          }, params: {}

          assert_response :unauthorized
        end

        test '/api/v4/auth/login - login with token in header as Token -> Unauthorized' do
          get api_v4_users_path, headers: {
            Token: @current_user.access_token
          }, params: {}

          assert_response :unauthorized
        end

        test '/api/v4/auth/login - login with JWT, signed with Private Key ' do
          rsa_private = generate_private_key
          token = DataCycleCore::JsonWebToken.encode(payload: { token: @current_user.access_token, iss: 'datacycle.at' }, alg: 'RS256', key: rsa_private).token

          post api_v4_authentication_login_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {
            email: @user_data[:email],
            password: @user_data[:password]
          }

          assert_response :success

          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data.dig('user', 'email')

          DataCycleCore.features[:user_api].delete(:public_keys)
        end

        test '/api/v4/auth/renew_login - renew current token' do
          token = DataCycleCore::JsonWebToken.encode(payload: { user_id: @current_user.id, jti: @current_user.jti }).token

          travel 23.hours

          post api_v4_authentication_renew_login_path, headers: {
            Authorization: "Bearer #{token}"
          }

          assert_response :success

          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @current_user.email, json_data.dig('user', 'email')

          travel 23.hours
          DataCycleCore::JsonWebToken.decode(json_data['token'])
        end

        test '/api/v4/users/create - create new user' do
          user_data = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
            email: "tester_2_#{Time.now.getutc.to_i}@datacycle.at",
            confirmed_at: Time.zone.now - 1.day
          })

          post api_v4_users_create_path, params: user_data.merge(token: @current_user.access_token).deep_transform_keys { |k| k.to_s.camelize(:lower) }, headers: {}

          assert_response :created
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal user_data['email'], json_data.dig('email')

          new_token = json_data['token']

          get api_v4_users_path, headers: {
            Authorization: "Bearer #{new_token}"
          }, params: {}

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'

          user_data['email'] = "tester_3_#{Time.now.getutc.to_i}@datacycle.at"

          post api_v4_users_create_path, headers: {
            Authorization: "Bearer #{new_token}"
          }, params: user_data.deep_transform_keys { |k| k.to_s.camelize(:lower) }

          assert_response :unauthorized
        end

        test '/api/v4/users/update - update user' do
          rsa_private = generate_private_key
          token = DataCycleCore::JsonWebToken.encode(payload: { user: @user_data.deep_transform_keys { |k| k.to_s.camelize(:lower) }, iss: 'datacycle.at' }, alg: 'RS256', key: rsa_private).token

          patch api_v4_users_update_path, params: { givenName: 'Test', familyName: 'Er' }, headers: {
            Authorization: "Bearer #{token}"
          }

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal 'Test', json_data['givenName']
          assert_equal 'Er', json_data['familyName']
        end

        test '/api/v4/users - login or create user on authenticate' do
          user_data = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
            email: "tester_3_#{Time.now.getutc.to_i}@datacycle.at",
            confirmed_at: Time.zone.now - 1.day
          })
          rsa_private = generate_private_key
          token = DataCycleCore::JsonWebToken.encode(payload: { user: user_data.deep_transform_keys { |k| k.to_s.camelize(:lower) }, iss: 'datacycle.at' }, alg: 'RS256', key: rsa_private).token

          get api_v4_users_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {}

          assert_response :success

          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)
          assert_equal user_data['email'], json_data.dig('@graph', 'userData', 'email')
          assert DataCycleCore::User.exists?(email: user_data['email'])

          user_data['family_name'] = 'Tester2'
          token = DataCycleCore::JsonWebToken.encode(payload: { user: user_data.deep_transform_keys { |k| k.camelize(:lower) }, iss: 'datacycle.at' }, alg: 'RS256', key: rsa_private).token

          get api_v4_users_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {}

          assert_response :success

          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse(response.body)
          assert_equal user_data['email'], json_data.dig('@graph', 'userData', 'email')
          assert_equal user_data['family_name'], DataCycleCore::User.find_by(email: user_data['email']).family_name

          DataCycleCore.features[:user_api].delete(:public_keys)
        end

        test 'POST /api/v4/users/password - reset password for user - not found' do
          rsa_private = generate_private_key
          token = DataCycleCore::JsonWebToken.encode(payload: { token: @current_user.access_token, iss: 'datacycle.at' }, alg: 'RS256', key: rsa_private).token

          post api_v4_users_password_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {
            email: @new_user.email
          }

          assert_response :success

          assert @new_user.reload.reset_password_period_valid?
        end
      end
    end
  end
end
