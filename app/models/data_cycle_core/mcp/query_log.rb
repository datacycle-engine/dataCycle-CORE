# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # A user's query history over MCP: records every tool call and reads it back for the
    # recent_queries tool. Writing and reading deliberately in ONE place -- otherwise the shape of an
    # entry cannot be kept constant between writer and display (an entry whose arguments are no
    # longer read is worthless as a "history", yet not visible as an error).
    #
    # Why persisted at all: the streamable HTTP transport runs with `stateless: true`, so every tool
    # call is its own HTTP request with a freshly built MCP::Server. Nothing survives in the process
    # after the response for a follow-up call to fall back on.
    #
    # Why `Activity` and not a table of its own: `User#log_request_activity` is the existing,
    # best-effort way to log user requests together with their request context
    # (controller/action/referer/origin) -- the REST APIs use it through `after_action :log_activity`.
    # MCP needs only its own `activity_type` and the tool arguments in `data` from it; a second table
    # with the same columns would be the same thing twice (cleanup, permissions and reporting
    # included).
    #
    # Where the history stops: it is written from the tool block (Tools::Publication#to_mcp_tool). A call
    # the mcp gem already rejects at the input_schema (unknown argument, missing required) never
    # reaches that block and is therefore NOT in the history -- MCP::Server validates the schema
    # before tool.call. So the history shows the queries that ran as queries, not every rejected
    # request. Anyone who wants those too has to start at the transport (controller), not here.
    module QueryLog
      ACTIVITY_TYPE = 'mcp'

      class << self
        # Writes a history entry for a tool call.
        #
        # @param context [Hash] server context of the tool (:current_user, :stored_filter, :request)
        # @param tool [Class] the Tools::Base subclass whose #call ran
        # @param arguments [Hash] the arguments of the call, unchanged -- they are the actual
        #   history: only with them is an earlier query repeatable rather than merely nameable.
        # @param result [Hash, Array, String, nil] return value of the tool (for the hit count)
        # @param error [StandardError, nil] on a failed call
        def record(context:, tool:, arguments:, result: nil, error: nil)
          return unless tool.record_queries?

          user = context[:current_user]
          return if user.nil?

          user.log_request_activity(
            type: ACTIVITY_TYPE,
            data: {
              tool: tool.tool_name,
              arguments: arguments.presence,
              count: count_of(result),
              error: error&.message
            }.compact,
            request: context[:request],
            # As in the REST logging (`activitiable: @collection`): on the endpoint mount the
            # entry hangs off the endpoint, instance-wide off none -- that is exactly what makes
            # the scope a number was measured against readable from the history.
            activitiable: context[:stored_filter]
          )
        rescue StandardError => e
          # Instrumentation must never turn a successful tool call into an error response: the
          # call in Tools::Publication#to_mcp_tool sits inside the rescue that builds the error response --
          # without this rescue, a write failure in the history would replace the tool's (correct)
          # result.
          Rails.logger.error("[Mcp::QueryLog] #{e.class}: #{e.message}")
          nil
        end

        # The user's most recent history entries, newest first.
        #
        # @param user [DataCycleCore::User]
        # @param limit [Integer]
        # @param tool [String, nil] only calls of this tool (tool_name)
        # @return [Array<Hash>]
        def recent(user:, limit:, tool: nil)
          return [] if user.nil?

          activities = user.activities.where(activity_type: ACTIVITY_TYPE).order(created_at: :desc)
          activities = activities.where("activities.data ->> 'tool' = ?", tool) if tool.present?

          activities.limit(limit).includes(:activitiable).map { |activity| entry(activity) }
        end

        private

        def entry(activity)
          data = activity.data || {}

          {
            tool: data['tool'],
            arguments: data['arguments'],
            count: data['count'],
            error: data['error'],
            endpoint: endpoint_of(activity),
            at: activity.created_at
          }.compact
        end

        def endpoint_of(activity)
          endpoint = activity.activitiable
          return if endpoint.nil?

          { id: endpoint.id, name: endpoint.try(:name) }.compact
        end

        # The hit count of the query, when the tool reports one (search_contents, facet_values,
        # resolve_concepts, ...). Without it the entry stays in the history, just without a number --
        # a get_content call has none.
        def count_of(result)
          result[:count] if result.is_a?(Hash)
        end
      end
    end
  end
end
