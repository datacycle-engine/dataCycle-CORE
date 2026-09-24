# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module Mcp
      # Global-mount equivalent of test/integration/api/v4/mcp/mcp_authorization_test.rb: proves
      # that every GlobalServer tool sits behind the same access boundary -- no token at all, and
      # no valid token -- rather than the endpoint-scoped `authorize! :api, @collection` gate,
      # which has no equivalent here (see Api::Mcp::McpController#require_authenticated_user!).
      class McpGlobalAuthorizationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        include DataCycleCore::McpTestHelper

        TOOL_ARGUMENTS = SCOPED_TOOL_ARGUMENTS.merge(
          'select_things' => { 'ids' => [SecureRandom.uuid] },
          'universal_lookup' => { 'id' => SecureRandom.uuid },
          'browse_concept_schemes' => {},
          'list_concepts' => { 'concept_scheme_id' => SecureRandom.uuid },
          'list_endpoints' => {},
          'get_schema' => {},
          'recent_queries' => {}
        ).freeze

        before(:all) do
          @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @user.update!(access_token: SecureRandom.hex) if @user.access_token.blank?
        end

        # The body, not only the status: it names WHICH layer rejected. Both messages come from
        # Warden -- Devise's `unauthenticated_json` when no token is sent, ApiTokenStrategy#fail!
        # when one is sent and does not resolve. That is the evidence the ROUTE carries the
        # guarantee: the mount sits inside the `authenticate do` block at config/routes.rb:296, so
        # no controller of it runs for an anonymous request and a guard inside one is unreachable.
        test 'tools/list without any token is rejected by warden, before any controller runs' do
          jsonrpc_post('tools/list', {})

          assert_response :unauthorized
          assert_equal 'invalid or missing authentication token', response.parsed_body.dig('errors', 0, 'detail')
        end

        test 'tools/list with an invalid token is rejected by warden, before any controller runs' do
          jsonrpc_post('tools/list', {}, token: 'not-a-real-token')

          assert_response :unauthorized
          assert_equal 'invalid authentication token', response.parsed_body.dig('errors', 0, 'detail')
        end

        test 'tools/list with a valid token succeeds and lists all global tools' do
          jsonrpc_post('tools/list', {}, token: @user.access_token)

          assert_response :success
          assert_equal DataCycleCore::Mcp::Servers::GlobalServer::TOOLS.size, response.parsed_body.dig('result', 'tools')&.size
        end

        # Guard against the map above going stale: a tool added to the server but not here would
        # simply not be checked, and the missing access-boundary test would look like a passing suite.
        test 'every global tool is covered by the access-boundary checks' do
          assert_equal DataCycleCore::Mcp::Servers::GlobalServer::TOOLS.map(&:tool_name).sort, TOOL_ARGUMENTS.keys.sort
        end

        TOOL_ARGUMENTS.each do |tool_name, arguments|
          test "tools/call #{tool_name} without any token is rejected" do
            jsonrpc_post('tools/call', { 'name' => tool_name, 'arguments' => arguments })

            assert_response :unauthorized
          end

          test "tools/call #{tool_name} with an invalid token is rejected" do
            jsonrpc_post('tools/call', { 'name' => tool_name, 'arguments' => arguments }, token: 'not-a-real-token')

            assert_response :unauthorized
          end

          test "tools/call #{tool_name} with a valid token passes the access gate" do
            jsonrpc_post('tools/call', { 'name' => tool_name, 'arguments' => arguments }, token: @user.access_token)

            assert_response :success
          end
        end
      end
    end
  end
end
