# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Servers
      # Registry and factory for the global MCP server: all base_query tools (SCOPED_TOOLS, scoped
      # instance-wide here through Mcp::ApiScope) plus the tools that deliberately reach beyond any
      # single result space -- concepts, endpoint discovery, schema, and the user's query history
      # (recent_queries), which spans every mount and therefore lives here only.
      class GlobalServer < Base
        # This mount's key under the mcp feature's :mounts -- Base#write_enabled? reads
        # :write_enabled beneath it and decides whether WRITE_TOOLS ship along, and
        # McpTransportConcern its :allowed_origins.
        MOUNT = :global

        TOOLS = (SCOPED_TOOLS + SHARED_TOOLS + [
          DataCycleCore::Mcp::Tools::SelectThings,
          DataCycleCore::Mcp::Tools::UniversalLookup,
          DataCycleCore::Mcp::Tools::BrowseConceptSchemes,
          DataCycleCore::Mcp::Tools::ListConcepts,
          DataCycleCore::Mcp::Tools::ListEndpoints,
          DataCycleCore::Mcp::Tools::GetSchema,
          DataCycleCore::Mcp::Tools::RecentQueries
        ]).freeze

        def initialize(context: {}, locale: I18n.default_locale)
          @context = context.merge(locale:)
          @locale = locale
        end

        private

        def server_name
          'datacycle-mcp'
        end

        # The shared tool descriptions name their scope through endpoint_name. Instance-wide there
        # is no endpoint name -- without a value I18n raises a MissingInterpolationArgument, and with
        # an empty value every description would carry a gap. Instead the interpolation names the
        # instance-wide scope (translated, like every other description), so the model knows what it
        # is searching across: that is the only difference from the endpoint server.
        def tool_description_options
          { locale:, endpoint_name: DataCycleCore::Mcp::Translations.t('scope.global', locale:) }
        end
      end
    end
  end
end
