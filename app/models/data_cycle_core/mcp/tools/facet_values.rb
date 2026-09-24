# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Returns the concepts (values) of a facet including content counts, filtered by a minimum
      # count -- the detail view of one entry from list_facets.
      class FacetValues < Base
        self.tool_name = 'facet_values'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              classification_tree_label_id: openapi_property('getEndpointFacets', 'classification_tree_label_id', locale:),
              # min_count_with_subtree/min_count_without_subtree: MCP's own filter knobs, with no
              # OpenAPI parameter counterpart -- hence by hand here rather than via openapi_property.
              min_count_with_subtree: { type: 'integer', description: argument_description('min_count_with_subtree', locale:) },
              min_count_without_subtree: { type: 'integer', description: argument_description('min_count_without_subtree', locale:) }
            },
            required: ['classification_tree_label_id']
          }
        end

        # Counts things per concept inside the endpoint scoped by base_query.
        # min_count_with_subtree deliberately defaults to 1: trees such as "Administrative Einheiten"
        # are seeded in full (>15,000 concepts), of which an endpoint occupies only a fraction. With
        # a default of 0 the answer was an unusable full-dump list in which the few productive
        # regions drowned -- clients then resorted to the full-text search.
        def call(arguments:, context:)
          concept_scheme_id = arguments[:classification_tree_label_id]

          concepts = DataCycleCore::Concept.thing_counts_for_tree(
            concept_scheme_id:,
            query: context[:base_query].query,
            min_count_with_subtree: (arguments[:min_count_with_subtree] || 1).to_i,
            min_count_without_subtree: (arguments[:min_count_without_subtree] || 0).to_i
          ).to_a

          parent_ids = parent_ids_for(concepts)
          ids_with_children = ids_with_children_for(concepts)

          {
            # The tree definition is repeated here although list_facets already supplies it:
            # facet_values is also called directly (with an id from browse_concept_schemes or from
            # an earlier step), and without the definition the value list is read without the
            # context that makes it interpretable.
            **scheme_description(concept_scheme_id, context),
            values: concepts.map do |c|
              {
                id: c.id,
                name: c.name,
                parent_id: parent_ids[c.id],
                is_leaf: ids_with_children.exclude?(c.id),
                thing_count_with_subtree: c.thing_count_with_subtree,
                thing_count_without_subtree: c.thing_count_without_subtree
              }
            end
          }
        end

        private

        # Name, metrics and curated definition of the tree -- splatted into the response, so that an
        # unknown id (or a tree without a definition) does not carry the fields at all rather than
        # carrying them empty.
        #
        # Without :id although describe_scheme supplies it: the caller has just passed the id as an
        # argument itself, and a bare "id" beside the values list reads like the id of a value rather
        # than that of the tree.
        def scheme_description(concept_scheme_id, context)
          scheme = DataCycleCore::ConceptScheme.find_by(id: concept_scheme_id)
          return {} if scheme.nil?

          describe_scheme(
            scheme,
            metrics: DataCycleCore::Mcp::ConceptSchemeMetrics.new(scheme_ids: [scheme.id], base_query: context[:base_query])
          ).except(:id)
        end

        # Without parent_id the response is a flat list in which parent and child nodes look
        # equal in rank: "Wandern", "Wanderweg", "Bergsteigen" and "Klettersteig" stand side by
        # side with no way to tell that the Klettersteig hangs under Bergsteigen. A client then
        # has to guess which concepts a user question ("Wanderung") covers, and filters on
        # different sets depending on how it guessed -- reproducibly different hit counts for the
        # same question.
        #
        # parent_id is nil on root nodes. It can point at a concept missing from values:
        # min_count_without_subtree can filter out pure grouping nodes (own count 0) while their
        # children remain.
        def parent_ids_for(concepts)
          return {} if concepts.blank?

          DataCycleCore::ConceptLink.broader
            .where(child_id: concepts.map(&:id))
            .pluck(:child_id, :parent_id)
            .to_h
        end

        # is_leaf refers to the tree, not to the filtered response: a node with exclusively empty
        # children is is_leaf false although no children appear in values. That keeps "filtering on
        # this concept pulls the subtree along" visible.
        def ids_with_children_for(concepts)
          return Set.new if concepts.blank?

          DataCycleCore::ConceptLink.broader
            .where(parent_id: concepts.map(&:id))
            .distinct
            .pluck(:parent_id)
            .to_set
        end
      end
    end
  end
end
