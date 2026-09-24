# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # A term -> ALL the concept UUIDs belonging to it, as a ready-made OR group for
      # search_contents. Replaces the instruction "please collect every variant yourself"
      # (list_concepts) with the execution -- see Mcp::ConceptResolver for the why and the measured
      # numbers.
      class ResolveConcepts < Base
        self.tool_name = 'resolve_concepts'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              term: { type: 'string', description: argument_description('term', locale:) },
              concept_scheme_ids: {
                type: 'array', items: { type: 'string', format: 'uuid' },
                description: argument_description('concept_scheme_ids', locale:)
              },
              include_empty: { type: 'boolean', description: argument_description('include_empty', locale:) },
              limit: { type: 'integer', minimum: 1, default: DataCycleCore::Mcp::ConceptResolver::DEFAULT_LIMIT, description: argument_description('limit', locale:) }
            },
            required: ['term']
          }
        end

        # Returns the union of the term's variants through the name search.
        def call(arguments:, context:)
          resolver = DataCycleCore::Mcp::ConceptResolver.new(base_query: context[:base_query], concept_schemes: concept_schemes_for(arguments, context))
          result = resolver.call(term: arguments[:term], include_empty: arguments[:include_empty] == true, limit: limit_from(arguments))

          add_warning(resolver.warnings)

          result
        end

        private

        # Explicitly passed trees are checked for API visibility but NOT against the endpoint's
        # curation: facet_values and search_contents accept non-curated trees too (a dimension
        # missing from list_facets is a curation gap, not a data finding), and behaving differently
        # here would cut that route off.
        def concept_schemes_for(arguments, context)
          ids = Array.wrap(arguments[:concept_scheme_ids]).compact_blank
          return DataCycleCore::Mcp::EndpointFacets.scope(context).to_a if ids.blank?

          DataCycleCore::ConceptScheme.where(internal: false).visible('api').where(id: ids).to_a
        end
      end
    end
  end
end
