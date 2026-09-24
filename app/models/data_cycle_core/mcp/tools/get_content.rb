# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Loads a single content by id from the mount's result space (context[:base_query]): inside an
      # endpoint its contents, instance-wide the user's api visibility scope. The batch variant over
      # several ids is SelectThings.
      class GetContent < Base
        self.tool_name = 'get_content'
        input_schema do |locale|
          {
            type: 'object',
            properties: { id: openapi_property('getEndpointContent', 'content_id', locale:) },
            required: ['id']
          }
        end

        # Loads the content by id and serializes it into a hash.
        def call(arguments:, context:)
          context[:base_query].query.find(arguments[:id]).to_h
        end
      end
    end
  end
end
