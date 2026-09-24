# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Aggregates content counts over time (attribute/group_by/time) via
      # ApiRenderer::StatisticsRenderer, inside the endpoint scoped by base_query.
      class Statistics < Base
        self.tool_name = 'statistics'
        # attribute: OpenAPI (getEndpointStatistics) documents this path parameter only as a free
        # string (no enum) -- the tool's enum is a deliberate enrichment, not a replacement.
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              attribute: { type: 'string', enum: ['dct:created', 'dct:modified'], description: argument_description('attribute', locale:) },
              group_by: openapi_property('getEndpointStatistics', 'groupBy', locale:),
              time: openapi_property('getEndpointStatistics', 'time', locale:)
            },
            required: ['attribute', 'group_by']
          }
        end

        # Renders the statistics for the endpoint scoped by base_query as a hash.
        def call(arguments:, context:)
          renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(
            query: context[:base_query].query,
            attribute: arguments[:attribute],
            group_by: arguments[:group_by],
            time: arguments[:time],
            data_format: 'object'
          )

          rendered_hash(renderer.render(:json))
        end
      end
    end
  end
end
