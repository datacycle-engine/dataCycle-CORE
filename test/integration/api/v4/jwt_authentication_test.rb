# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class JwtAuthenticationTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @current_user = User.find_by(email: 'tester@datacycle.at')
          @current_user.update_column(:access_token, SecureRandom.hex) # rubocop:disable Rails/SkipsModelValidations

          @user_data = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
            email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
            role_id: DataCycleCore::Role.find_by(rank: 5)&.id
          })
          @new_user = DataCycleCore::User.create(@user_data)
        end

        test '/api/v4/auth/login - login with token' do
          post api_v4_auth_login_path, params: {}, headers: {}
          assert_response 401

          post api_v4_auth_login_path, params: {
            email: @user_data[:email],
            password: @user_data[:password],
            token: @current_user.access_token
          }, headers: {}

          assert_response 200
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data['email']

          new_token = json_data['token']

          post api_v4_auth_login_path, headers: {
            Authorization: "Bearer #{new_token}"
          }, params: {
            email: @user_data[:email],
            password: @user_data[:password]
          }

          assert_response 200
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data['email']
        end

        test '/api/v4/auth/login - login with JWT, signed with Secret' do
          @current_user.update_column(:jti, SecureRandom.uuid) # rubocop:disable Rails/SkipsModelValidations
          token = DataCycleCore::JsonWebToken.encode(payload: { user_id: @current_user.id, jti: @current_user.jti })

          post api_v4_auth_login_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {
            email: @user_data[:email],
            password: @user_data[:password]
          }

          assert_response 200

          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data['email']
        end

        test '/api/v4/auth/login - login with JWT, signed with Private Key ' do
          rsa_private = OpenSSL::PKey::RSA.generate 2048
          rsa_public = rsa_private.public_key

          DataCycleCore.features[:user_api][:public_keys] = { 'datacycle.at': rsa_public.to_s }

          token = DataCycleCore::JsonWebToken.encode(payload: { token: @current_user.access_token }, alg: 'RS256', key: rsa_private)

          post api_v4_auth_login_path, headers: {
            Authorization: "Bearer #{token}"
          }, params: {
            email: @user_data[:email],
            password: @user_data[:password]
          }

          assert_response 200

          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal @user_data['email'], json_data['email']

          DataCycleCore.features[:user_api].delete(:public_keys)
        end

        test '/api/v4/users - create new user' do
          user_data = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
            email: "tester_2_#{Time.now.getutc.to_i}@datacycle.at"
          })

          post api_v4_users_path, params: {
            user: user_data,
            token: @current_user.access_token
          }, headers: {}

          assert_response 201
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse(response.body)

          assert json_data['token'].present?
          assert_equal user_data['email'], json_data['email']

          new_token = json_data['token']

          get api_v4_users_path, headers: {
            Authorization: "Bearer #{new_token}"
          }, params: {}

          assert_response 200
          assert_equal response.content_type, 'application/json'
        end
      end
    end
  end
end
