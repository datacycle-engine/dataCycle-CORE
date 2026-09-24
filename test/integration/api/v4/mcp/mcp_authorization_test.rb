# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V4
      module Mcp
        # Proves that every MCP tool enforces the exact same access boundary as its REST
        # sibling: all of them run through FilterConcern#build_search_query's single
        # `authorize! :api, @collection` gate (see Api::V4::McpController#create). Access is
        # denied identically to the REST routes for: no token, an invalid token, and a valid
        # token against a StoredFilter with api: false (CollectionByCreatorAndApi and
        # CollectionByApiAndShared* all require api: true, so api: false blocks everyone --
        # including the creator; StoredFilterAuthorizationTest states the rule itself).
        class McpAuthorizationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::McpTestHelper

          TOOL_ARGUMENTS = SCOPED_TOOL_ARGUMENTS.merge(
            'download' => { 'format' => 'json' }
          ).freeze

          before(:all) do
            @creator = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
            @creator.update!(access_token: SecureRandom.hex) if @creator.access_token.blank?
            @accessible_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp auth test - accessible',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Event'] }]
            )
            @inaccessible_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp auth test - inaccessible',
              user_id: @creator.id,
              api: false,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Event'] }]
            )
          end

          test 'tools/list without any token is rejected like the REST routes' do
            jsonrpc_post('tools/list', {}, endpoint_id: @accessible_endpoint.id)

            assert_response :unauthorized
          end

          test 'tools/list with an invalid token is rejected like the REST routes' do
            jsonrpc_post('tools/list', {}, token: 'not-a-real-token', endpoint_id: @accessible_endpoint.id)

            assert_response :unauthorized
          end

          test 'tools/list with a valid token against an api:false endpoint is rejected like the REST routes' do
            jsonrpc_post('tools/list', {}, token: @creator.access_token, endpoint_id: @inaccessible_endpoint.id)

            assert_response :unauthorized
          end

          test 'tools/list with a valid token against an api:true endpoint succeeds' do
            jsonrpc_post('tools/list', {}, token: @creator.access_token, endpoint_id: @accessible_endpoint.id)

            assert_response :success
            assert_equal DataCycleCore::Mcp::Servers::SingleEndpointServer::TOOLS.size, response.parsed_body.dig('result', 'tools')&.size
          end

          # Guard against the map above going stale: a tool added to the server but not here would
          # simply not be checked, and the missing access-boundary test would look like a passing suite.
          test 'every endpoint tool is covered by the access-boundary checks' do
            assert_equal DataCycleCore::Mcp::Servers::SingleEndpointServer::TOOLS.map(&:tool_name).sort, TOOL_ARGUMENTS.keys.sort
          end

          TOOL_ARGUMENTS.each do |tool_name, arguments|
            test "tools/call #{tool_name} with an invalid token is rejected like the REST routes" do
              jsonrpc_post('tools/call', { 'name' => tool_name, 'arguments' => arguments }, token: 'not-a-real-token', endpoint_id: @accessible_endpoint.id)

              assert_response :unauthorized
            end

            test "tools/call #{tool_name} against an api:false endpoint is rejected like the REST routes" do
              jsonrpc_post('tools/call', { 'name' => tool_name, 'arguments' => arguments }, token: @creator.access_token, endpoint_id: @inaccessible_endpoint.id)

              assert_response :unauthorized
            end

            test "tools/call #{tool_name} with a valid token against an api:true endpoint passes the access gate" do
              jsonrpc_post('tools/call', { 'name' => tool_name, 'arguments' => arguments }, token: @creator.access_token, endpoint_id: @accessible_endpoint.id)

              assert_response :success
            end
          end
        end
      end
    end
  end
end
