# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Servers
      # The shared registry and factory scaffolding of the MCP servers. Subclasses declare only
      # their TOOLS and their MOUNT and implement #server_name (plus #tool_description_options
      # where needed); the version, the shared RESOURCES/RESOURCE_TEMPLATES/WRITE_TOOLS and the
      # MCP::Server assembly live here so that global_server.rb and single_endpoint_server.rb do not
      # carry them twice.
      class Base
        # The version both servers report to every client. Taken from the gem version (GEM_VERSION,
        # read from the gemspec) rather than a literal: as a fixed '0.1.0' it had stood there since
        # the first commit and told a client nothing about which state it was facing -- a client
        # that aligns its behaviour with the server version saw every change as the same version.
        #
        # The fallback is only for the case where the gemspec is not loaded (e.g. running from an
        # unpacked directory without Bundler): then a recognisably empty version instead of an
        # invented number.
        VERSION = Gem.loaded_specs['data_cycle_core']&.version&.to_s || '0.0.0'

        # Tools that take their result space exclusively from context[:base_query] and therefore run
        # on EVERY mount that brings one: the StoredFilter inside an endpoint, the user's api
        # visibility scope instance-wide (Mcp::ApiScope). One list for both servers rather than an
        # enumeration per server -- otherwise a client cannot explain why the same question is
        # unanswerable on the global mount, and the two lists drift apart again with every new tool.
        #
        # NOT here: `download` (it needs the id of a PERSISTED StoredFilter for the download URL,
        # which does not exist instance-wide) and the tools that deliberately reach beyond any one
        # result space (concepts, endpoint discovery, schema, query history) -- those sit in the
        # GlobalServer.
        SCOPED_TOOLS = [
          DataCycleCore::Mcp::Tools::SearchContents,
          DataCycleCore::Mcp::Tools::GetContent,
          DataCycleCore::Mcp::Tools::Suggest,
          DataCycleCore::Mcp::Tools::SuggestByTitle,
          DataCycleCore::Mcp::Tools::ListFacets,
          DataCycleCore::Mcp::Tools::FacetValues,
          DataCycleCore::Mcp::Tools::ResolveConcepts,
          DataCycleCore::Mcp::Tools::ListAttributes,
          DataCycleCore::Mcp::Tools::ResolvePlace,
          DataCycleCore::Mcp::Tools::ListTemplates,
          DataCycleCore::Mcp::Tools::Statistics,
          DataCycleCore::Mcp::Tools::Timeseries,
          DataCycleCore::Mcp::Tools::ElevationProfile
        ].freeze

        # On BOTH mounts, but not in SCOPED_TOOLS, because describe_endpoint is the only tool that
        # can also describe a result space OTHER than its own (endpoint_id): without an argument the
        # mount's, with one that of any endpoint released to the user, whose base_query it then
        # builds itself (Mcp::ApiScope).
        #
        # On both mounts, because both questions are real: instance-wide "which endpoint suits my
        # question" (after list_endpoints, which deliberately measures no content volumes), and on
        # the endpoint mount "what does the endpoint I am attached to carry" -- there the client
        # knows only its URL and cannot name its own endpoint at all.
        SHARED_TOOLS = [
          DataCycleCore::Mcp::Tools::DescribeEndpoint
        ].freeze

        RESOURCES = [
          DataCycleCore::Mcp::Resources::SchemaIndex
        ].freeze

        RESOURCE_TEMPLATES = [
          DataCycleCore::Mcp::Resources::SchemaTemplate
        ].freeze

        # The writing tools are a separate set switched by configuration (write_enabled under the
        # respective MOUNT, default false): an existing installation stays read-only after an
        # upgrade until it releases writing explicitly. Both servers share the same set -- the
        # endpoint scope is a read filter and does not restrict write permissions; in both cases the
        # boundary is the token's ability (see Mcp::ContentWriter).
        WRITE_TOOLS = [
          DataCycleCore::Mcp::Tools::ListWritableAttributes,
          DataCycleCore::Mcp::Tools::CreateContent,
          DataCycleCore::Mcp::Tools::UpdateContent
        ].freeze

        # Entry points the USER can pick in the client (see Prompts::Base). The same for both
        # mounts: they describe a task, not a result space.
        PROMPTS = [
          DataCycleCore::Mcp::Prompts::InventoryQuestion
        ].freeze

        # Bound to write_enabled in parallel with WRITE_TOOLS -- a write prompt in the selection
        # list of a read-only mount would be a promise no tool can keep.
        WRITE_PROMPTS = [
          DataCycleCore::Mcp::Prompts::WriteContent
        ].freeze

        # Builds the MCP::Server instance with the subclass's tools and resources.
        def call
          MCP::Server.new(
            name: server_name,
            version: VERSION,
            instructions:,
            # locale in addition to the finished description: it goes into the input_schema, whose
            # argument descriptions are localized as well (Tools::Base#argument_description).
            tools: tool_classes.map { |t| t.to_mcp_tool(description: t.description(**tool_description_options), locale:) },
            prompts: prompt_classes.map { |p| p.to_mcp_prompt(locale:) },
            resources: self.class::RESOURCES.map { |r| r.to_mcp_resource(description: r.description(locale:)) },
            resource_templates: self.class::RESOURCE_TEMPLATES.map { |r| r.to_mcp_resource_template(description: r.description(locale:)) },
            # tool_names in the context: describe_endpoint judges the tools of THIS mount and must
            # not enumerate them itself -- a second list inside the tool would be silently wrong
            # under write_enabled or at the next mount-specific tool (download, list_endpoints). Set
            # here and not in initialize, because only tool_classes accounts for the release.
            server_context: @context.merge(tool_names: tool_classes.map(&:tool_name)),
            configuration:
          )
        end

        private

        # Checks every tool result against Tools::Publication::OUTPUT_SCHEMA. The gem validates only
        # when asked (validate_tool_call_results defaults to false), and a declared schema that
        # nothing checks is a promise to the client we never keep -- a tool answering outside the
        # envelope now fails at the call rather than shipping a response the client cannot rely on.
        #
        # Per server and not through MCP.configure, which is process-wide. validate_tool_call_arguments
        # is passed along deliberately: Configuration#merge takes it from the given object
        # unconditionally -- unlike protocol_version, which it takes only when that object sets it --
        # so omitting it here would reset a host's global value to the default.
        def configuration
          MCP::Configuration.new(
            validate_tool_call_results: true,
            validate_tool_call_arguments: MCP.configuration.validate_tool_call_arguments
          )
        end

        # @return [Symbol] locale for the resource descriptions.
        attr_reader :locale

        # Mount-wide text for initialize/discover (see Mcp::ServerInstructions). Here and not per
        # server, because the two differ only in the result-space block -- and that follows from
        # instruction_options, exactly as it does for the tool descriptions.
        def instructions
          DataCycleCore::Mcp::ServerInstructions.new(locale:, write_enabled: write_enabled?, **instruction_options).call
        end

        # @return [Hash] mount-specific values for the instructions. Empty = global mount; the
        # endpoint server adds its endpoint_name.
        def instruction_options
          {}
        end

        # @return [Array<Class>] the subclass's read tools, plus WRITE_TOOLS when released.
        def tool_classes
          write_enabled? ? self.class::TOOLS + WRITE_TOOLS : self.class::TOOLS
        end

        # @return [Array<Class>] prompts, bound to the same release as the tools.
        def prompt_classes
          write_enabled? ? PROMPTS + WRITE_PROMPTS : PROMPTS
        end

        def write_enabled?
          DataCycleCore::Feature::Mcp.write_enabled?(self.class::MOUNT)
        end

        # @return [String] name of the MCP server (subclass-specific).
        def server_name
          raise NotImplementedError, "#{self.class} must implement #server_name"
        end

        # @return [Hash] keyword arguments for every tool's #description.
        def tool_description_options
          { locale: }
        end
      end
    end
  end
end
