# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Lists concepts (classification aliases) within a concept scheme, optionally filtered by a
      # search term, otherwise only the topmost concepts (roots) of the tree.
      class ListConcepts < Base
        self.tool_name = 'list_concepts'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              concept_scheme_id: openapi_property('getConcepts', 'id', locale:, extra: argument_description('concept_scheme_id', locale:)),
              search: openapi_property('getConcepts', 'search', locale:, extra: argument_description('search', locale:)),
              # limit: MCP's own convenience parameter, with no OpenAPI counterpart.
              limit: { type: 'integer', minimum: 1, default: 50, description: argument_description('limit', locale:) }
            },
            required: ['concept_scheme_id']
          }
        end

        # context stays unused: concepts are global, not endpoint-scoped.
        def call(arguments:, context:) # rubocop:disable Lint/UnusedMethodArgument -- fixed Tool#call interface (Publication#to_mcp_tool)
          concept_scheme = DataCycleCore::ConceptScheme.where(internal: false).visible('api').find(arguments[:concept_scheme_id])
          limit = limit_from(arguments)

          concepts = arguments[:search].present? ? concept_scheme.concepts.search(arguments[:search]) : concept_scheme.concepts.roots
          concepts = concepts.limit(limit).to_a
          counts = thing_counts(concept_scheme, concepts)

          {
            concepts: concepts.map { |concept| { id: concept.id, name: concept.name, thing_count: counts[concept.id].to_i } }
          }
        end

        private

        # A count per concept, so the rule "never just take the first match" is verifiable rather
        # than merely urged: a search for "vegan" returns four concepts, and without the numbers
        # beside them there is no way to see that three of them are populated (17 / 25 / 42, union
        # 81) -- whoever takes the first reports 17 and is off by a factor of 5.
        #
        # Counted instance-wide (this tool is not endpoint-scoped) and without embedded contents,
        # which never appear as hits in their own right. The number serves to compare the sizes of
        # the variants, not as an endpoint's hit count -- facet_values supplies that.
        def thing_counts(concept_scheme, concepts)
          return {} if concepts.blank?

          DataCycleCore::Concept
            .thing_counts_for_tree(
              concept_scheme_id: concept_scheme.id,
              query: DataCycleCore::Thing.where.not(content_type: 'embedded'),
              min_count_with_subtree: 0
            )
            .where(id: concepts.map(&:id))
            .to_h { |c| [c.id, c.thing_count_with_subtree] }
        end
      end
    end
  end
end
