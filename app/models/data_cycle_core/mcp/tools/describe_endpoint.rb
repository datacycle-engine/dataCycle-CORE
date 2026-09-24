# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # The profile of an endpoint: content volume, templates, the detail dimensions it carries
      # (geodata, elevation data, schedules, images, time series, classifications, filterable
      # attributes, relations) and, per tool, a verdict on whether it answers anything here
      # (Mcp::EndpointProfile).
      #
      # ONE tool for all endpoints, with endpoint_id as an argument, rather than one per endpoint:
      # the answer is measured entirely from the respective result space, so there is nothing
      # endpoint-specific to program. A tool per endpoint would instead mean that every newly
      # created endpoint (a record, not code) would stand there without a description -- and a
      # client would get a tool list that grows with the number of endpoints.
      #
      # Without an argument the tool describes the result space of its own mount. That is the common
      # case on the endpoint mount, where a client cannot name its endpoint at all: it knows only
      # the URL it is connected under.
      class DescribeEndpoint < Base
        self.tool_name = 'describe_endpoint'

        input_schema do |locale|
          {
            type: 'object',
            properties: {
              endpoint_id: {
                type: 'string',
                format: 'uuid',
                description: argument_description('endpoint_id', locale:)
              }
            }
          }
        end

        # Returns the profile of the described endpoint (see Mcp::EndpointProfile#call).
        def call(arguments:, context:)
          stored_filter, base_query, queryable_here = scope_for(arguments[:endpoint_id], context)

          DataCycleCore::Mcp::EndpointProfile.new(
            stored_filter:,
            base_query:,
            tool_names: Array.wrap(context[:tool_names]),
            queryable_here:,
            locale: locale_from(arguments, context).first
          ).call
        end

        private

        # Without an endpoint_id (or with that of its own mount) the result space the server
        # already carries is used -- NOT a second, freshly built one: on the endpoint mount
        # base_query carries the controller's language and filter decisions
        # (Api::V4::McpController), and a filter rebuilt here would differ in exactly the numbers
        # reported beside it as the mount's profile.
        #
        # With a foreign endpoint_id, the same scope as in list_endpoints
        # (StoredFilter.accessible_by(ability, :api).named): only what the user would be allowed to
        # query is describable. An unknown or unreleased endpoint raises RecordNotFound and becomes
        # an error response (Mcp::ErrorMapper) -- not, silently, the profile of its own mount, which
        # would look like an answer to the question asked.
        def scope_for(endpoint_id, context)
          own = context[:stored_filter]
          return [own, context[:base_query], true] if endpoint_id.blank? || endpoint_id == own&.id

          endpoint = DataCycleCore::StoredFilter.accessible_by(context[:ability], :api).named.find(endpoint_id)

          [endpoint, DataCycleCore::Mcp::ApiScope.new(current_user: context[:current_user], stored_filter: endpoint).base_query, false]
        end
      end
    end
  end
end
