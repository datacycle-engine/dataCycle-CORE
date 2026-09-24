# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Typeahead suggestions over the full-text index of the endpoint scoped by base_query.
      class Suggest < Base
        self.tool_name = 'suggest'
        # locale: MCP's own convenience parameter (the language of the typeahead index), with no
        # OpenAPI counterpart -- text and limit are now derived from suggestEndpoint.
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              text: openapi_property('suggestEndpoint', 'search', locale:),
              locale: { type: 'string', description: argument_description('locale', locale:, default_value: locale) },
              limit: openapi_property('suggestEndpoint', 'limit', locale:)
            },
            required: ['text']
          }
        end

        # Returns word suggestions with their score for the entered text prefix.
        def call(arguments:, context:)
          # The fallback is the session's language (context[:locale], set by both servers) and NO
          # longer the literal 'de': a mount asked for 'en' would otherwise silently return
          # suggestions from the German typeahead index, and the argument description ("default
          # <session language>") would be a promise the code does not keep (see #locale_from).
          locale = locale_from(arguments, context)
          limit = limit_from(arguments)

          result = context[:base_query].typeahead(arguments[:text], locale, limit)
          { suggestions: result.to_a.map { |row| { word: row['word'], score: row['score'] } } }
        end
      end
    end
  end
end
