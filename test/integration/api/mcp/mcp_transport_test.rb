# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module Mcp
      # The handover of the MCP transport's Rack response to Rails (McpTransportConcern) -- the part
      # the tool suites do NOT cover: they call exclusively methods with a result and read only the
      # JSON body of it.
      #
      # The concern replaces a `render(json: body.first, status:, headers:)` that carried two bugs:
      # actionpack knows no :headers option (the transport headers were silently discarded), and
      # `render json: nil` turns an empty body into the JSON literal `null`. That `null` is exactly
      # the case an MCP client sees in reply to a NOTIFICATION -- per JSON-RPC a notification has no
      # response, so a `null` body violates the protocol.
      #
      # Both mounts share the concern, hence both are here: the global one (/api/mcp) and the
      # endpoint-scoped one (/api/v4/endpoints/:id/mcp). A test on only one mount would not notice a
      # regression in the other (a reinstated render, say).
      class McpTransportTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        include DataCycleCore::McpTestHelper

        before(:all) do
          @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @user.update!(access_token: SecureRandom.hex) if @user.access_token.blank?

          @endpoint = DataCycleCore::StoredFilter.create!(
            name: 'mcp transport test',
            user_id: @user.id,
            api: true,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel'] }]
          )
        end

        test 'notifications/initialized is answered with an empty 202 body on the global mount' do
          jsonrpc_post('notifications/initialized', {}, id: nil, token: @user.access_token)

          assert_response :accepted
          assert_empty response.body, 'a notification must get no body -- "null" violates the protocol'
        end

        test 'notifications/initialized is answered with an empty 202 body on the endpoint mount' do
          jsonrpc_post('notifications/initialized', {}, id: nil, token: @user.access_token, endpoint_id: @endpoint.id)

          assert_response :accepted
          assert_empty response.body, 'a notification must get no body -- "null" violates the protocol'
        end

        # Counter-check: the same code path must still deliver a method WITH a result as JSON.
        # Without it the concern could be shortened to "always head" and the test would stay green.
        test 'a method with a result is still rendered as json on both mounts' do
          jsonrpc_post('tools/list', {}, token: @user.access_token)

          assert_response :success
          assert_predicate response.parsed_body.dig('result', 'tools'), :present?, 'the global mount returns no result'

          jsonrpc_post('tools/list', {}, token: @user.access_token, endpoint_id: @endpoint.id)

          assert_response :success
          assert_predicate response.parsed_body.dig('result', 'tools'), :present?, 'the endpoint mount returns no result'
        end

        # The transport's headers belong on the response. In stateless mode that is only the
        # Content-Type -- which is exactly why the loss went unnoticed, and exactly why a test stands
        # here: switched to `stateless: false`, the session id would hang off the same path.
        test 'transport headers reach the response instead of being swallowed by render' do
          jsonrpc_post('tools/list', {}, token: @user.access_token)

          assert_response :success
          assert_includes response.headers['Content-Type'].to_s, 'application/json'
        end

        # The transport is handed Rails' config.hosts. Drop that and the gem's loopback-only default
        # takes over: on a real host EVERY request answers "403 Invalid Host header", which from the
        # outside is indistinguishable from a permission error and which no other test would catch --
        # jsonrpc_post speaks to localhost, and localhost is a loopback default.
        #
        # ActionDispatch::HostAuthorization does not stand in the way here: Rails only inserts that
        # middleware when config.hosts is non-empty at boot, and in the test environment it is empty,
        # so what this asserts is the transport's own check.
        test 'a host configured in config.hosts is accepted, an unconfigured one is rejected' do
          Rails.application.config.hosts << 'mcp.example.com'

          jsonrpc_post('tools/list', {}, token: @user.access_token, host: 'mcp.example.com')

          assert_response :success

          jsonrpc_post('tools/list', {}, token: @user.access_token, host: 'rebound.example.com')

          assert_response :forbidden
        ensure
          Rails.application.config.hosts.delete('mcp.example.com')
        end

        # subscriptions/listen is the one method the transport answers with an SSE stream instead of
        # a JSON body, and these controllers cannot serve one -- ActionController::API brings no
        # ActionController::Live, so render_mcp_transport_response raises on the streaming body.
        # serve_subscriptions_listen: false turns that 500 into the -32601 below.
        #
        # Only the modern lifecycle (MCP 2026-07-28) reaches the stream, and only fully formed: the
        # MCP-Protocol-Version and Mcp-Method headers, the SEP-2575 `_meta` envelope and a
        # `notifications` filter. Every step short of that is refused earlier for its own reason, so
        # a smaller request would pass whether the switch is set or not.
        test 'subscriptions/listen is answered as unimplemented rather than opening a stream' do
          post '/api/mcp',
               params: {
                 jsonrpc: '2.0', id: 1, method: 'subscriptions/listen',
                 params: {
                   '_meta' => {
                     'io.modelcontextprotocol/protocolVersion' => '2026-07-28',
                     'io.modelcontextprotocol/clientCapabilities' => {}
                   },
                   'notifications' => {}
                 }
               },
               as: :json,
               headers: {
                 'Accept' => 'application/json, text/event-stream',
                 'Host' => 'localhost',
                 'Authorization' => "Bearer #{@user.access_token}",
                 'MCP-Protocol-Version' => '2026-07-28',
                 'Mcp-Method' => 'subscriptions/listen'
               }

          assert_equal(-32_601, response.parsed_body.dig('error', 'code'))
        end
      end
    end
  end
end
