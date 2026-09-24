# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      # Endpoint-scoped MCP endpoint (a StoredFilter as the scope) -- POST
      # /api/v4/endpoints/:id/mcp, streamable HTTP transport from the mcp gem. Counterpart to
      # Api::Mcp::McpController (global there).
      #
      # It deliberately inherits from Api::V4::ApiBaseController and includes FilterConcern: that
      # provides #build_search_query -- StoredFilter resolution, the CanCan gate, caching and locale
      # handling exactly as the REST routes beside it do, instead of rebuilding auth parity here.
      # The global mount knows no endpoint concept and is conversely kept deliberately lean.
      class McpController < ApiBaseController
        before_action :prepare_url_parameters

        include DataCycleCore::FilterConcern
        include DataCycleCore::McpTransportConcern

        # Handles a single streamable HTTP request against the SingleEndpointServer.
        def create
          # Without this line build_search_query scopes base_query through prepare_url_parameters
          # to [I18n.default_locale] -> contents without a de translation are missing from the count
          # (e.g. people without a de title). Why 'all' and why the same value for both mounts: see
          # DataCycleCore::Mcp::QUERY_LANGUAGE. An explicitly requested language stays decisive.
          @language = DataCycleCore::Mcp::QUERY_LANGUAGE if permitted_params[:language].blank?

          base_query = build_search_query

          handle_mcp_request(server(base_query), DataCycleCore::Mcp::Servers::SingleEndpointServer::MOUNT)
        end

        private

        def permitted_parameter_keys
          super + [:id, :language]
        end

        def server(base_query)
          DataCycleCore::Mcp::Servers::SingleEndpointServer.new(
            stored_filter: @stored_filter,
            base_query:,
            # request: only for the query history (Mcp::QueryLog -> User#log_request_activity).
            context: { current_user:, ability: current_ability, base_url: request.base_url, request: }
          ).call
        end
      end
    end
  end
end
