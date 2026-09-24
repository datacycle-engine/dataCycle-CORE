# frozen_string_literal: true

module DataCycleCore
  module McpTestHelper
    # tools/call arguments for every tool both mounts expose (Mcp::Servers::Base::SCOPED_TOOLS plus
    # SHARED_TOOLS). Both authorization suites
    # check it against their own access gate -- so the map lives here once instead of per suite,
    # where the two copies would drift apart with the next tool (each suite asserts completeness
    # against its server's TOOLS, so a missing entry fails instead of silently skipping a tool).
    SCOPED_TOOL_ARGUMENTS = {
      'search_contents' => {},
      'get_content' => { 'id' => SecureRandom.uuid },
      'suggest' => { 'text' => 'a' },
      'suggest_by_title' => { 'text' => 'a' },
      'list_facets' => {},
      'facet_values' => { 'classification_tree_label_id' => SecureRandom.uuid },
      'resolve_concepts' => {},
      'list_attributes' => {},
      'resolve_place' => { 'place' => 'Vorarlberg' },
      'list_templates' => {},
      'statistics' => { 'attribute' => 'dct:created', 'group_by' => 'day' },
      'timeseries' => { 'id' => SecureRandom.uuid, 'attribute' => 'x' },
      'elevation_profile' => { 'id' => SecureRandom.uuid },
      'describe_endpoint' => {}
    }.freeze

    # Shared JSON-RPC POST helper for the MCP integration test suites (single-endpoint vs.
    # global mount, tools vs. authorization) -- one place for the transport quirk below
    # instead of copy-pasting it per file. `endpoint_id: nil` posts to the global mount
    # (`/api/mcp`), otherwise to the endpoint-scoped mount (`/api/v4/endpoints/:id/mcp`).
    # language: the language parameter BOTH mounts read from the query (globally through
    # #request_locale, at the endpoint through permitted_params) -- as a query parameter and not as a
    # header, because that is where the controllers expect it.
    # id: the JSON-RPC request id. `id: nil` does NOT send it at all and thereby makes the call a
    # NOTIFICATION -- the difference is protocol-relevant and not cosmetic: the server answers a
    # notification with 202 and an empty body, whereas a message with an id always gets a result.
    # `notifications/initialized` WITH an id is consequently acknowledged as "Method not found".
    def jsonrpc_post(method, params, token: nil, endpoint_id: nil, language: nil, id: 1, host: 'localhost')
      # StreamableHTTPTransport's default DNS-rebinding guard only allows the loopback
      # hosts (127.0.0.1/::1/localhost); Rails' integration test default host
      # (www.example.com) is not among them, so it must be set explicitly here.
      headers = { 'Accept' => 'application/json, text/event-stream', 'Host' => host }
      headers['Authorization'] = "Bearer #{token}" if token

      path = endpoint_id ? api_v4_mcp_path(id: endpoint_id) : '/api/mcp'
      path = "#{path}?language=#{language}" if language.present?

      body = { jsonrpc: '2.0', method:, params: }
      body[:id] = id unless id.nil?

      post path, params: body, as: :json, headers:
    end

    # Releases the write tools on the named mounts for the block. Here rather than per test file
    # because Feature::Mcp memoizes its configuration: the reload has to happen INSIDE the stubbed
    # window and again afterwards, and a copy that forgets the second one leaks the write tools into
    # whatever test runs next.
    # No argument means every mount, taken from the feature's own list so a third one would be
    # covered without a change here.
    def with_write_enabled(*mounts)
      mounts = DataCycleCore::Feature::Mcp::MOUNTS if mounts.blank?
      features = DataCycleCore.features.deep_dup
      mounts.each { |mount| features['mcp']['mounts'][mount.to_s]['write_enabled'] = true }

      DataCycleCore.stub(:features, features) do
        DataCycleCore::Feature::Mcp.reload
        yield
      end
    ensure
      DataCycleCore::Feature::Mcp.reload
    end

    # Sets the geo cascade's configuration (the :geo block of Feature::Mcp) for a test. Here rather
    # than per test file, because the unit and the integration test need the same configuration.
    #
    # Through the shared feature config and NOT through define_singleton_method on the feature
    # class: its accessors are defined inside `class << self`, so a define_singleton_method
    # overwrites the real implementation at that same place -- and the later remove_method then
    # removes not the stub but the method itself, which is missing for the rest of the worker
    # process. Going through the config also exercises the accessors instead of stubbing them away.
    # Resetting happens centrally (MinitestHookHelper restores the pristine snapshot at the start of
    # every test class); within a class #reset_geo_scope_feature does it.
    # locality_prefixes is a parameter like the rest and defaults to none, although the gem does
    # ship prefixes: a test that needs "Gemeinde Testdorf" to match the address locality "Testdorf"
    # says so itself rather than depending on the shipped list staying as it is.
    def stub_geo_scope_feature(resolution_trees:, geo_region_trees: [], postal_code_patterns: {}, locality_prefixes: [], enabled: true)
      shipped = DataCycleCore::MinitestHookHelper.pristine_features&.dig(:mcp) || {}

      # deep_merge and only under :geo, because the mounts live in the same feature now: a flat
      # merge would drop :mounts and with it the routes every MCP suite needs.
      write_mcp_feature(
        shipped.deep_dup.with_indifferent_access.deep_merge(
          'geo' => { 'enabled' => enabled, 'resolution_trees' => resolution_trees, 'geo_region_trees' => geo_region_trees, 'postal_code_patterns' => postal_code_patterns, 'locality_prefixes' => locality_prefixes }
        )
      )
    end

    def reset_geo_scope_feature
      write_mcp_feature(DataCycleCore::MinitestHookHelper.pristine_features&.dig(:mcp)&.deep_dup)
    end

    private

    # Through the mattr writer, not `DataCycleCore.features[:mcp] = ...`:
    # MinitestHookHelper.reset_features! installs the pristine snapshot frozen at the start of
    # every test class, so a Hash#[]= on it raises FrozenError. Only the top level is frozen, and
    # replacing the whole hash is the way the snapshot is meant to be overridden.
    def write_mcp_feature(config)
      DataCycleCore.features = DataCycleCore.features.merge(mcp: config)

      DataCycleCore::Feature::Mcp.reload
    end
  end
end
