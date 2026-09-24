# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Typeahead suggestions based on content titles (rather than the full-text index, as Suggest
      # uses).
      class SuggestByTitle < Base
        self.tool_name = 'suggest_by_title'
        # locale: see Suggest.
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              text: openapi_property('suggestEndpointByTitle', 'search', locale:),
              locale: { type: 'string', description: argument_description('locale', locale:, default_value: locale) },
              limit: openapi_property('suggestEndpointByTitle', 'limit', locale:)
            },
            required: ['text']
          }
        end

        # Returns title suggestions for the entered text prefix.
        def call(arguments:, context:)
          # The session language rather than the literal 'de' -- see Suggest.
          locale = locale_from(arguments, context)
          limit = limit_from(arguments)

          { suggestions: context[:base_query].typeahead_by_title(arguments[:text], locale, limit) }
        end
      end
    end
  end
end
