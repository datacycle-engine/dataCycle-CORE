# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # The calling user's query history: which MCP tools were called with which arguments and what
      # hit count came out -- across every mount, because a user asks their question on the global
      # and on the endpoint server and the history would otherwise be a different one per server. It
      # is written in Tools::Publication#to_mcp_tool, see Mcp::QueryLog.
      class RecentQueries < Base
        self.tool_name = 'recent_queries'
        # It reads the history and is therefore not itself a query that belongs in it: otherwise,
        # after asking twice, the history consists mostly of the asking.
        self.record_queries = false

        input_schema do |locale|
          {
            type: 'object',
            properties: {
              limit: { type: 'integer', minimum: 1, default: 10, description: argument_description('limit', locale:) },
              tool: { type: 'string', description: argument_description('tool', locale:) }
            }
          }
        end

        # @return [Hash] { queries: [{ tool:, arguments:, count:, endpoint:, at: }, ...] }
        def call(arguments:, context:)
          queries = DataCycleCore::Mcp::QueryLog.recent(
            user: context[:current_user],
            limit: limit_from(arguments),
            tool: arguments[:tool]
          )

          { queries: }
        end
      end
    end
  end
end
