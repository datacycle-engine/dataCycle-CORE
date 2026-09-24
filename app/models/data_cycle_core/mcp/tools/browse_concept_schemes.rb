# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Lists the publicly visible concept schemes, optionally filtered by a search term -- the
      # entry point before list_concepts needs an id.
      class BrowseConceptSchemes < Base
        self.tool_name = 'browse_concept_schemes'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              search: openapi_property('getConceptSchemes', 'search', locale:)
            }
          }
        end

        # WHICH schemes get listed is global and not endpoint-scoped -- that is the difference from
        # list_facets. The context is needed all the same: thing_count counts in the caller's result
        # space (Base#describe_schemes), so a tree that is populated instance-wide but empty for this
        # user stays recognisable as empty and is not read as a filter candidate that then returns 0
        # hits.
        def call(arguments:, context:)
          schemes = DataCycleCore::ConceptScheme.where(internal: false).visible('api')
          schemes = schemes.search(arguments[:search]) if arguments[:search].present?

          { schemes: describe_schemes(schemes, context) }
        end
      end
    end
  end
end
