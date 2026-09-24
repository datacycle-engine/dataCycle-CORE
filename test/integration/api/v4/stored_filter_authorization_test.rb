# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V4
      # States the access rule for an endpoint with api: true, for the detail route and for the
      # listing alike: its creator reads it (CollectionByCreatorAndApi), everybody else only
      # through an explicit share with their user, user group or role (CollectionByApiAndShared*).
      #
      # A public rule on top of those - stored_filter_api_public, every role reads every endpoint -
      # travelled in with the OpenAPI feature (#50127) and was removed a week later. Every other
      # api test owns the endpoint it queries and stays green either way; only a foreign caller
      # tells the two rules apart.
      class StoredFilterAuthorizationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @creator = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @creator.update!(access_token: SecureRandom.hex) if @creator.access_token.blank?

          @foreign_user = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
          @foreign_user.update!(access_token: SecureRandom.hex) if @foreign_user.access_token.blank?

          @user_group = DataCycleCore::UserGroup.create!(name: 'stored filter authorization test')
          DataCycleCore::UserGroupUser.create!(user_group_id: @user_group.id, user_id: @foreign_user.id)

          @unshared_endpoint = create_endpoint('unshared')
          @user_shared_endpoint = create_endpoint('shared with user', shared_users: [@foreign_user])
          @group_shared_endpoint = create_endpoint('shared with user group', shared_user_groups: [@user_group])
          @role_shared_endpoint = create_endpoint('shared with role', shared_roles: [@foreign_user.role])
        end

        test 'the creator reads their own endpoint' do
          get_endpoint(@unshared_endpoint, @creator)

          assert_response :success
        end

        test 'a foreign user without a share is rejected' do
          get_endpoint(@unshared_endpoint, @foreign_user)

          assert_response :unauthorized
        end

        test 'a foreign user with a user share reads the endpoint' do
          get_endpoint(@user_shared_endpoint, @foreign_user)

          assert_response :success
        end

        test 'a foreign user with a user group share reads the endpoint' do
          get_endpoint(@group_shared_endpoint, @foreign_user)

          assert_response :success
        end

        test 'a foreign user with a role share reads the endpoint' do
          get_endpoint(@role_shared_endpoint, @foreign_user)

          assert_response :success
        end

        test 'GET /api/v4/endpoints lists the shared endpoints and leaves out the unshared one' do
          get api_v4_endpoints_path, headers: authorization_header(@foreign_user)

          assert_response :success
          ids = response.parsed_body['@graph'].pluck('@id')

          assert_includes ids, @user_shared_endpoint.id
          assert_includes ids, @group_shared_endpoint.id
          assert_includes ids, @role_shared_endpoint.id
          assert_not_includes ids, @unshared_endpoint.id
        end

        private

        def create_endpoint(name, shares = {})
          DataCycleCore::StoredFilter.create!({
            name: "stored filter authorization test - #{name}",
            user_id: @creator.id,
            api: true,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Event'] }]
          }.merge(shares))
        end

        def get_endpoint(endpoint, user)
          get api_v4_stored_filter_path(id: endpoint.id), headers: authorization_header(user)
        end

        def authorization_header(user)
          { Authorization: "Bearer #{user.access_token}" }
        end
      end
    end
  end
end
