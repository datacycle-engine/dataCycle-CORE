# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Returns the time-series history of an attribute for a content via
      # ApiRenderer::TimeseriesRenderer.
      class Timeseries < Base
        self.tool_name = 'timeseries'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              id: openapi_property('getEndpointTimeseries', 'content_id', locale:, extra: argument_description('id', locale:)),
              attribute: openapi_property('getEndpointTimeseries', 'timeseries', locale:, extra: argument_description('attribute', locale:)),
              group_by: openapi_property('getEndpointTimeseries', 'groupBy', locale:),
              time: openapi_property('getEndpointTimeseries', 'time', locale:)
            },
            required: ['id', 'attribute']
          }
        end

        # Renders the time series for the content referenced by id as a hash.
        def call(arguments:, context:)
          content = context[:base_query].query.find(arguments[:id])

          renderer = DataCycleCore::ApiRenderer::TimeseriesRenderer.new(
            content:,
            timeseries: arguments[:attribute],
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
