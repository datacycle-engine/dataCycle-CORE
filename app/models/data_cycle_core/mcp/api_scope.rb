# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The result space of the global mount -- the endpoint-less counterpart to the single-endpoint
    # server's `base_query` (which comes from FilterConcern#build_search_query there). It gives BOTH
    # mounts the same `context[:base_query]`, so every tool built on it (search_contents,
    # facet_values, resolve_concepts, ...) runs instance-wide through exactly the same code as
    # inside an endpoint: the difference is the scope alone, not the tool implementation.
    #
    # Visibility semantics as in Api::V4::ApiBaseController#authorize_api_content!: a user without
    # configured api scope filters gets an unrestricted query -- existing REST parity, not
    # introduced here.
    class ApiScope
      # @param stored_filter [DataCycleCore::StoredFilter, nil] nil = instance-wide (the normal case
      #   on the global mount). With an endpoint it yields the same result space that the endpoint
      #   mount serves under its own URL -- needed by Tools::DescribeEndpoint, which must be able to
      #   describe an endpoint the client is not attached to. The caller is responsible for the user
      #   being allowed to see that endpoint (accessible_by(ability, :api)); the api user filter here
      #   is the visibility of the CONTENTS, not the release of the endpoint.
      def initialize(current_user:, stored_filter: nil)
        @current_user = current_user
        @stored_filter = stored_filter
      end

      # Builds the same filter as build_search_query (without an endpoint id: `StoredFilter.new` plus
      # the api user filter), but without its REST parameter machinery (MCP knows no
      # paging/include/fields/sort from query parameters -- sorting and limit come from the tool
      # arguments instead).
      #
      # CAUTION: a passed endpoint is MODIFIED in the process (language, parameters) and stays dirty
      # and unsaved -- exactly as in build_search_query, which works on @stored_filter itself. No
      # dup: `cached` hangs off the id of the persisted record. Anyone rendering a maintained
      # attribute of the endpoint afterwards must therefore read it from the database (see
      # Mcp::EndpointProfile#endpoint), and nobody may save the record afterwards.
      #
      # @return [DataCycleCore::Filter::Search]
      def base_query
        @base_query ||= begin
          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = DataCycleCore::Mcp::QUERY_LANGUAGE
          filter.apply_user_filter(@current_user, { scope: 'api' })
          filter.cached.apply
        end
      end
    end
  end
end
