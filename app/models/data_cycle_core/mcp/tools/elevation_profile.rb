# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Returns the elevation profile of a line geometry (a content with elevation data) via
      # ApiRenderer::ElevationProfileRenderer.
      class ElevationProfile < Base
        self.tool_name = 'elevation_profile'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              id: openapi_property('getElevationProfile', 'content_id', locale:, extra: argument_description('id', locale:))
            },
            required: ['id']
          }
        end

        # Renders the elevation profile for the content referenced by id.
        def call(arguments:, context:)
          content = context[:base_query].query.find(arguments[:id])

          renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content:, data_format: 'object')

          rendered_hash(renderer.render)
        end
      end
    end
  end
end
