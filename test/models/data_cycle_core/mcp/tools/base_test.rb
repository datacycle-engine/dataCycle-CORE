# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    module Tools
      # Behaviour of the shared Tools::Base helpers. Deliberately against anonymous tool classes
      # rather than a real tool: the assertions hold for EVERY tool, and a concrete tool would only
      # bring its own schema shape along here (and need the database for it -- openapi_property).
      class BaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
        # @param limit_property [Hash, nil] the input_schema's limit property (nil = none)
        def tool_class(limit_property, name: 'dummy_tool')
          properties = limit_property.nil? ? {} : { limit: limit_property }

          Class.new(DataCycleCore::Mcp::Tools::Base) do
            self.tool_name = name
            input_schema { { type: 'object', properties: } }
          end
        end

        test 'default_limit reads the JSON-Schema default' do
          assert_equal 25, tool_class({ type: 'integer', default: 25 }).default_limit
        end

        test 'limit_from prefers the argument over the schema default' do
          tool = tool_class({ type: 'integer', default: 20 }).new

          assert_equal 5, tool.send(:limit_from, { limit: 5 })
        end

        test 'limit_from falls back to the schema default' do
          tool = tool_class({ type: 'integer', default: 20 }).new

          assert_equal 20, tool.send(:limit_from, {})
          assert_equal 20, tool.send(:limit_from, { limit: nil })
        end

        # The reason for the raise: nil.to_i would be a limit of 0, i.e. an empty hit list inside a
        # successful response -- indistinguishable from the result "nothing found".
        test 'limit_from raises instead of limiting to zero when no default is declared' do
          tool = tool_class({ type: 'integer' }).new

          error = assert_raises(RuntimeError) { tool.send(:limit_from, {}) }
          assert_match(/no 'default' for its limit property/, error.message)
        end

        test 'locale_from prefers the argument, then the mount, then the instance default' do
          tool = tool_class(nil).new

          assert_equal [:en], tool.send(:locale_from, { locale: 'en' }, { locale: :fr })
          assert_equal [:fr], tool.send(:locale_from, {}, { locale: :fr })
          assert_equal [I18n.default_locale], tool.send(:locale_from, {}, {})
          assert_equal [I18n.default_locale], tool.send(:locale_from, { locale: '' }, {})
        end

        # The mcp gem splats the arguments as keywords, so ONLY the top level is symbolized --
        # nested objects stay the string-keyed hashes from the JSON. Measured:
        # arguments[:near].keys == ["lat", "lon"], arguments[:near][:lat] == nil.
        #
        # An access with a symbol silently returned nil there, the affected filter or sort came out
        # ineffective, and applied_filters still reported it as applied (demonstrated with
        # sort: distance + near, see SortScopeTest). That is why Base normalises the arguments at the
        # entrance -- the test pins that for EVERY tool, future ones included.
        test 'a tool sees nested arguments under both key forms' do
          seen = nil
          klass = tool_class(nil, name: 'nested_arguments_tool')
          klass.record_queries = false
          klass.define_method(:call) { |arguments:, context:| seen = arguments } # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface

          klass.to_mcp_tool(description: 'x').call(server_context: {}, near: { 'lat' => 47.1, 'lon' => 9.8 })

          assert_in_delta 47.1, seen[:near][:lat], 0.001, 'a nested access by symbol must return the value'
          assert_in_delta 47.1, seen[:near]['lat'], 0.001, 'the original string access must keep working'
        end

        # Every tool answers in the same envelope, so a client learns one shape instead of 25 and can
        # tell a status key from a payload key. Against a dummy tool, because the assertion is about
        # to_mcp_tool and must hold for a tool that does not exist yet.
        test 'a result is published inside the shared envelope' do
          klass = tool_class(nil, name: 'envelope_tool')
          klass.record_queries = false
          klass.define_method(:call) { |arguments:, context:| { total: 3 } } # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface

          response = klass.to_mcp_tool(description: 'x').call(server_context: {}).to_h

          assert_equal({ ok: true, data: { total: 3 } }, response[:structuredContent])
          # The text block carries the SAME envelope: it is what a client without structuredContent
          # support reads, and before the envelope the two could differ.
          assert_equal JSON.generate(response[:structuredContent]), response[:content].first[:text]
        end

        # Warnings say the answer beside them rests on a filter that did not take effect, so they
        # must reach a client that reads only the envelope. Absent rather than [] when there are
        # none: a key that is empty on almost every response trains a client to skip it.
        test 'warnings travel in the envelope and the key is absent without them' do
          klass = tool_class(nil, name: 'warning_tool')
          klass.record_queries = false
          klass.define_method(:call) do |arguments:, context:| # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface
            add_warning('filtered nothing')
            { total: 0 }
          end

          warned = klass.to_mcp_tool(description: 'x').call(server_context: {}).to_h

          assert_equal({ ok: true, data: { total: 0 }, warnings: ['filtered nothing'] }, warned[:structuredContent])

          quiet = tool_class(nil, name: 'quiet_tool')
          quiet.record_queries = false
          quiet.define_method(:call) { |arguments:, context:| { total: 0 } } # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface

          assert_not quiet.to_mcp_tool(description: 'x').call(server_context: {}).to_h[:structuredContent].key?(:warnings)
        end

        # Each call gets its own tool instance, so a warning from one request must not appear in the
        # next -- the collector is instance state and would leak if to_mcp_tool ever hoisted the
        # instance out of the block.
        test 'warnings do not leak from one call into the next' do
          klass = tool_class(nil, name: 'once_warning_tool')
          klass.record_queries = false
          klass.define_method(:call) do |arguments:, context:| # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface
            add_warning('once')
            {}
          end

          published = klass.to_mcp_tool(description: 'x')
          published.call(server_context: {})

          assert_equal ['once'], published.call(server_context: {}).to_h.dig(:structuredContent, :warnings)
        end

        # The seam between the point ceiling and the envelope: Mcp::SeriesPayload thins the payload,
        # and the notice about it has to reach a client that reads only the envelope -- inside the
        # payload's meta alone it is exactly the diagnostic most clients never look up.
        test 'a thinned renderer payload warns through the envelope' do
          size = DataCycleCore::Mcp::SeriesPayload::MAX_POINTS * 2
          klass = tool_class(nil, name: 'series_tool')
          klass.record_queries = false
          klass.define_method(:call) do |arguments:, context:| # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface
            rendered_hash({ 'data' => Array.new(size) { |i| { 'x' => i } } })
          end

          envelope = klass.to_mcp_tool(description: 'x').call(server_context: {}).to_h[:structuredContent]

          assert_equal size, envelope.dig(:data, 'meta', 'point_count')
          assert_equal 1, envelope[:warnings].size
        end

        # A failure keeps the {errors: [{source:, title:, detail:}]} shape Mcp::ErrorMapper shares
        # with the REST API -- the envelope adds ok: false beside it rather than nesting it, so a
        # client that already reads REST errors needs nothing new.
        test 'a failed call is published as ok false beside the REST error shape' do
          klass = tool_class(nil, name: 'failing_tool')
          klass.record_queries = false
          klass.define_method(:call) { |arguments:, context:| raise 'boom' } # rubocop:disable Lint/UnusedBlockArgument -- fixed Tool#call interface

          response = klass.to_mcp_tool(description: 'x').call(server_context: {}).to_h

          assert response[:isError]
          assert_not response[:structuredContent][:ok]
          assert_predicate response[:structuredContent][:errors].first[:title], :present?
        end

        test 'description_key falls back to the tool_name' do
          assert_equal 'dummy_tool', tool_class(nil).description_key
        end

        test 'description_key stays overridable for tools sharing a description' do
          klass = tool_class(nil)
          klass.description_key = 'shared_key'

          assert_equal 'shared_key', klass.description_key
        end
      end
    end
  end
end
