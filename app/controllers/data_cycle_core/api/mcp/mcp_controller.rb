# frozen_string_literal: true

module DataCycleCore
  module Api
    module Mcp
      # Global MCP endpoint (all tools, no endpoint scope) -- POST /api/mcp, streamable HTTP
      # transport from the mcp gem. Counterpart to Api::V4::McpController (endpoint-scoped there).
      #
      # No authentication guard of its own: the mount sits inside the `authenticate do` block at
      # config/routes.rb:296, so Warden rejects an anonymous or unresolvable token before any action
      # here runs -- current_user cannot be nil by the time #create is reached. The endpoint mount's
      # `authorize! :api, @collection` has no counterpart here because there is no endpoint to
      # authorize; the token itself is the boundary, and what a user then SEES comes from their api
      # scope filters (Mcp::ApiScope). Both rejections are pinned in mcp_global_authorization_test.
      class McpController < ApiBaseController
        include DataCycleCore::McpTransportConcern

        # Handles a single streamable HTTP request against the GlobalServer.
        def create
          handle_mcp_request(server, DataCycleCore::Mcp::Servers::GlobalServer::MOUNT)
        end

        private

        # base_query: the instance-wide counterpart to FilterConcern#build_search_query (see
        # Mcp::ApiScope) -- with it the shared search and facet tools run here under the same
        # result-space contract as on the endpoint mount. request: only for the query history
        # (Mcp::QueryLog passes it on to User#log_request_activity, as the REST logging does).
        def server
          DataCycleCore::Mcp::Servers::GlobalServer.new(
            context: {
              current_user:,
              ability: current_ability,
              base_query: DataCycleCore::Mcp::ApiScope.new(current_user:).base_query,
              request:
            },
            locale: request_locale
          ).call
        end

        def request_locale
          language = params[:language].presence
          language.in?(I18n.available_locales.map(&:to_s)) ? language.to_sym : I18n.default_locale
        end
      end
    end
  end
end
