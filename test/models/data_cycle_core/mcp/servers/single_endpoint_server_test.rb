# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    module Servers
      # Unit tests for SingleEndpointServer#call itself -- the locale-resolution, description-
      # interpolation and context-merge logic that the class implements. Complements
      # test/integration/api/v4/mcp/{mcp_tools_test,mcp_authorization_test}.rb, which exercise the
      # built MCP::Server end-to-end over HTTP but never assert on the construction logic below
      # (both integration suites always call through with @endpoint.language left unset).
      class SingleEndpointServerTest < DataCycleCore::TestCases::ActiveSupportTestCase
        include DataCycleCore::McpTestHelper

        before(:all) do
          @endpoint_first_wins = DataCycleCore::StoredFilter.create!(name: 'single endpoint server test - multi language', language: ['en', 'de'])
          @endpoint_no_language = DataCycleCore::StoredFilter.create!(name: 'single endpoint server test - no language', language: nil)
          @endpoint_all_language = DataCycleCore::StoredFilter.create!(name: 'single endpoint server test - all language', language: ['all'])
          @endpoint_all_then_real = DataCycleCore::StoredFilter.create!(name: 'single endpoint server test - all then real language', language: ['all', 'en'])
        end

        test 'call registers the protocol identity and the endpoint-scoped tool/resource registries from the class constants' do
          server = build_server(@endpoint_no_language).call

          assert_equal 'datacycle-mcp-endpoint', server.name
          # Against the gem version, not against a literal: otherwise the test only checks that two
          # identical strings sit in the repo, and the version would stay frozen forever.
          assert_equal Gem.loaded_specs['data_cycle_core'].version.to_s, server.version
          assert_equal SingleEndpointServer::TOOLS.map(&:tool_name).sort, server.tools.keys.sort
          assert_equal SingleEndpointServer::RESOURCES.map(&:uri), server.resources.map(&:uri)
          assert_equal SingleEndpointServer::RESOURCES.map(&:resource_name), server.resources.map(&:resource_name)
          assert_equal SingleEndpointServer::RESOURCE_TEMPLATES.map(&:uri_template), server.resource_templates.map(&:uri_template)
        end

        # An output schema nothing validates is a promise to the client we never keep, and the gem
        # leaves validate_tool_call_results off. Asserted on the BUILT server because the value
        # reaches it through Configuration#merge, which takes validate_tool_call_arguments from the
        # object we pass unconditionally -- so a careless configuration here switches ARGUMENT
        # validation off as a side effect, and nothing else would notice.
        test 'call builds a server that validates tool results as well as arguments' do
          configuration = build_server(@endpoint_no_language).call.configuration

          assert configuration.validate_tool_call_results, 'results must be checked against OUTPUT_SCHEMA'
          assert configuration.validate_tool_call_arguments, 'argument validation must survive the result setting'
        end

        test 'call resolves the locale from the first entry of stored_filter.language and interpolates the endpoint name' do
          server = build_server(@endpoint_first_wins).call
          tool_class = DataCycleCore::Mcp::Tools::SearchContents
          expected_description = tool_class.description(locale: :en, endpoint_name: @endpoint_first_wins.name)

          assert_equal expected_description, server.tools[tool_class.tool_name].description
          assert_not_equal tool_class.description(locale: :de, endpoint_name: @endpoint_first_wins.name), server.tools[tool_class.tool_name].description
          assert_includes server.tools[tool_class.tool_name].description, @endpoint_first_wins.name
        end

        test 'call falls back to I18n.default_locale when stored_filter.language is blank' do
          server = build_server(@endpoint_no_language).call
          tool_class = DataCycleCore::Mcp::Tools::SearchContents
          expected_description = tool_class.description(locale: I18n.default_locale, endpoint_name: @endpoint_no_language.name)

          assert_equal expected_description, server.tools[tool_class.tool_name].description
        end

        # Api::V4::McpController sets language to ['all'] whenever the request does not ask for a
        # specific one -- a data scope, not an I18n locale. Taken over unchecked it produced
        # "translation missing: all.mcp.tools.<tool>.description" for EVERY tool of EVERY
        # endpoint-scoped server, i.e. clients received the tools without any description at all.
        test 'call skips the "all" data scope and falls back to I18n.default_locale' do
          server = build_server(@endpoint_all_language).call
          tool_class = DataCycleCore::Mcp::Tools::SearchContents
          description = server.tools[tool_class.tool_name].description

          assert_equal tool_class.description(locale: I18n.default_locale, endpoint_name: @endpoint_all_language.name), description
          assert_not_includes description, 'translation missing'
        end

        test 'call picks the first real locale when "all" precedes it' do
          server = build_server(@endpoint_all_then_real).call
          tool_class = DataCycleCore::Mcp::Tools::SearchContents

          assert_equal tool_class.description(locale: :en, endpoint_name: @endpoint_all_then_real.name), server.tools[tool_class.tool_name].description
        end

        # The seam at which the resolved locale reaches the SCHEMA: to_mcp_tool receives it in
        # addition to the finished description. Were the locale: to fall away there, the tool
        # descriptions would stay localized and only the argument descriptions would silently fall
        # back to I18n.default_locale -- an English client would get English tools with German
        # arguments, i.e. exactly the state the locale cache in Tools::Base fixed. Without this test
        # the whole suite would stay green through it: the contract test checks
        # Tools::Base.input_schema directly and would never come past this line.
        test 'call builds the tool input_schemas in the resolved locale, not the default one' do
          tool_class = DataCycleCore::Mcp::Tools::SearchContents
          built = build_server(@endpoint_first_wins).call.tools[tool_class.tool_name].input_schema.to_h
          description = built.deep_symbolize_keys.dig(:properties, :query, :description)

          assert_equal tool_class.input_schema(locale: :en).dig(:properties, :query, :description), description
          assert_not_equal tool_class.input_schema(locale: I18n.default_locale).dig(:properties, :query, :description), description
        end

        # The instructions are the only text a client sees before its first tool call
        # (initialize/discover). On the endpoint mount it has to name the endpoint -- without that a
        # client takes the curated subset for the whole inventory.
        test 'call passes the endpoint-scoped instructions, in the resolved locale' do
          server = build_server(@endpoint_first_wins).call

          assert_equal(
            DataCycleCore::Mcp::ServerInstructions.new(locale: :en, write_enabled: false, endpoint_name: @endpoint_first_wins.name).call,
            server.instructions
          )
          assert_includes server.instructions, @endpoint_first_wins.name
          assert_not_includes server.instructions, 'translation missing'
        end

        test 'call announces the write tools in the instructions when write_enabled is on' do
          read_only_instructions = build_server(@endpoint_no_language).call.instructions

          with_write_enabled(:endpoint) do
            instructions = build_server(@endpoint_no_language).call.instructions

            assert_not_equal read_only_instructions, instructions
            assert_includes instructions, DataCycleCore::Mcp::Translations.t('instructions.write_enabled', locale: I18n.default_locale)
          end
        end

        test 'call merges the constructor context, with the base_query/stored_filter arguments taking precedence over identically named context keys' do
          base_query = @endpoint_no_language.send(:default_query)
          caller_context = { current_user: 'caller-supplied user', base_query: 'stale base_query', stored_filter: 'stale stored_filter' }

          server = SingleEndpointServer.new(stored_filter: @endpoint_no_language, base_query:, context: caller_context).call

          assert_equal 'caller-supplied user', server.server_context[:current_user]
          assert_same base_query, server.server_context[:base_query]
          assert_same @endpoint_no_language, server.server_context[:stored_filter]
        end

        # The resolved locale belongs in the context too, not only in the descriptions: it is read
        # there by Resources::SchemaIndex (the schema's language) and by the write tools (the default
        # write language). Without the key both silently fell back to I18n.default_locale -- the same
        # call returned the requested language on the global mount and the instance's default
        # language here.
        test 'call puts the resolved locale into the context, like the global server does' do
          assert_equal :en, build_server(@endpoint_first_wins).call.server_context[:locale]
          assert_equal I18n.default_locale, build_server(@endpoint_all_language).call.server_context[:locale]
        end

        # The writing tools hang off api.v4.mcp.write_enabled (default false). Without this test, a
        # default accidentally flipped to true would show up only in the integration tests, which
        # stub the flag themselves anyway.
        # A write prompt in the selection list of a read-only mount would be a promise no tool can
        # keep -- the user picks it in the client and gets an error.
        test 'call registers the write prompt only together with the write tools' do
          assert_equal Servers::Base::PROMPTS.map(&:prompt_name), build_server(@endpoint_no_language).call.prompts.keys

          with_write_enabled(:endpoint) do
            assert_equal(
              (Servers::Base::PROMPTS + Servers::Base::WRITE_PROMPTS).map(&:prompt_name).sort,
              build_server(@endpoint_no_language).call.prompts.keys.sort
            )
          end
        end

        test 'call registers only the read tools while write_enabled is off' do
          server = build_server(@endpoint_no_language).call

          assert_equal SingleEndpointServer::TOOLS.map(&:tool_name).sort, server.tools.keys.sort
          assert_not_includes server.tools.keys, 'create_content'
        end

        test 'call adds the write tools when write_enabled is on' do
          with_write_enabled(:endpoint) do
            server = build_server(@endpoint_no_language).call

            assert_equal (SingleEndpointServer::TOOLS + SingleEndpointServer::WRITE_TOOLS).map(&:tool_name).sort, server.tools.keys.sort
            assert_predicate server.tools['create_content'].description, :present?
            assert_not_includes server.tools['create_content'].description, 'translation missing'
          end
        end

        private

        def build_server(stored_filter)
          SingleEndpointServer.new(stored_filter:, base_query: stored_filter.send(:default_query), context: {})
        end
      end
    end
  end
end
