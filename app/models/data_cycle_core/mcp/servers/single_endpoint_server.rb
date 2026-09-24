# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Servers
      # Registry and factory for an MCP server scoped to one endpoint (a StoredFilter): the shared
      # base_query tools (SCOPED_TOOLS) plus `download`, the only one that needs the id of a
      # persisted StoredFilter and therefore exists here only.
      class SingleEndpointServer < Base
        MOUNT = :endpoint

        TOOLS = (SCOPED_TOOLS + SHARED_TOOLS + [
          DataCycleCore::Mcp::Tools::Download
        ]).freeze

        # locale in the context as in the GlobalServer: the tools and resources that need a language
        # read it there (Resources::SchemaIndex, and the write tools as their default write
        # language). Were the key missing here, the same request would hang on the mount's output
        # format: create_content without a locale argument wrote in the requested language on the
        # global mount and in the instance's default language on the endpoint mount -- and the schema
        # always came back in German here although the endpoint is set to 'en'.
        def initialize(stored_filter:, base_query:, context: {})
          @stored_filter = stored_filter
          @locale = description_locale
          @context = context.merge(base_query:, stored_filter:, locale: @locale)
        end

        private

        def server_name
          'datacycle-mcp-endpoint'
        end

        # stored_filter.language is a data scope, not an I18n locale: Api::V4::McpController
        # deliberately sets it to ['all'] (counts across every translation, see there). ':all' is not
        # an available locale -- taken over unchecked, EVERY tool and resource description of this
        # server returned "translation missing: all.mcp.tools.<tool>.description", i.e. the client
        # got the tools without any description at all. Hence only real locales are taken over.
        def description_locale
          Array(@stored_filter.language)
            .filter_map { |l| l.to_sym if I18n.available_locales.include?(l.to_sym) }
            .first || I18n.default_locale
        end

        # Endpoint tools take the endpoint name in addition to the locale.
        def tool_description_options
          { locale:, endpoint_name: @stored_filter.name }
        end

        # In ServerInstructions the endpoint name selects the result-space block and is named inside
        # it: "the contents of endpoint X" rather than "every content you are allowed to see".
        def instruction_options
          { endpoint_name: @stored_filter.name }
        end
      end
    end
  end
end
