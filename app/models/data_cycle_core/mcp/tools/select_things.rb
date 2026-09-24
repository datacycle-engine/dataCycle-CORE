# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Loads several things by a list of ids from the result space (base_query) -- the batch
      # counterpart to get_content, which takes only a single id.
      class SelectThings < Base
        self.tool_name = 'select_things'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              ids: openapi_property('selectThings', 'uuid[]', locale:),
              limit: { type: 'integer', minimum: 1, default: 20, description: argument_description('limit', locale:) }
            },
            required: ['ids']
          }
        end

        # Loads the things by ids (up to limit) and condenses them into a brief overview.
        def call(arguments:, context:)
          limit = limit_from(arguments)
          things = context[:base_query].query.where(id: arguments[:ids]).limit(limit).to_a

          { count: things.size, items: things.map { |thing| summarize_thing(thing) } }
        end
      end
    end
  end
end
