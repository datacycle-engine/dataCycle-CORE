# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Measured metrics of the classification trees that list_facets/browse_concept_schemes/
    # facet_values ship along: structure (concept_count, depth) and occupancy (thing_count).
    #
    # Why measured instead of written into the curated definition: the numbers used to sit as prose
    # in config/locales/{de,en}.mcp.yml ("297 concepts", "2,409 contents carry an assignment", as of
    # 2026-07-31). A client cannot tell from a description how old its numbers are -- it reads them
    # as a current finding and reports them onwards. After every import they were wrong, without the
    # response making that visible. The definition therefore carries only the judgement (dimension,
    # structure, pitfall); the numbers come from here.
    #
    # Batched, not per tree: list_facets describes all trees of an endpoint in one response, so a
    # query per tree would be an N+1 on exactly the discovery path an LLM calls first.
    class ConceptSchemeMetrics
      # @param scheme_ids [Array<String>] the ConceptScheme ids being described
      # @param base_query [DataCycleCore::Filter::Search, nil] result space of the mount for
      #   thing_count (endpoint or instance-wide, see Mcp::ApiScope). nil = no result space, in
      #   which case thing_count is absent from the response.
      def initialize(scheme_ids:, base_query: nil)
        @scheme_ids = Array.wrap(scheme_ids).compact.uniq
        @base_query = base_query
      end

      # @return [Hash] the metrics of one tree, empty values omitted.
      def for(scheme_id)
        {
          concept_count: structure.dig(scheme_id, :concept_count) || 0,
          depth: structure.dig(scheme_id, :depth),
          thing_count: thing_counts&.fetch(scheme_id, 0)
        }.compact
      end

      private

      # concept_count/depth per tree in ONE query. Both are structure and therefore independent of
      # the result space: a tree has the same concepts whichever mount you look at it through --
      # unlike thing_count. The response names the two separately so that "the tree has 297
      # concepts" is not read as "297 categories are occupied in this endpoint".
      #
      # reorder(nil): the concepts' default scope sorts by order_a, which Postgres rejects under
      # GROUP BY.
      #
      # depth = number of levels: full_path_ids holds a concept's path up to the root, so its length
      # is that concept's level and the maximum is the depth of the tree. The value is exact per
      # scheme because a concept carries a single concept_scheme_id. LEFT JOIN so a concept without
      # a path row (the table is maintained by trigger) does not silently drop out of concept_count
      # -- depth then stays nil and the field is omitted instead of claiming too small a depth.
      def structure
        @structure ||= DataCycleCore::Concept
          .joins('LEFT JOIN concept_paths ON concept_paths.id = concepts.id')
          .where(concept_scheme_id: @scheme_ids)
          .reorder(nil)
          .group(:concept_scheme_id)
          .pluck(
            Arel.sql('concepts.concept_scheme_id'),
            Arel.sql('COUNT(DISTINCT concepts.id)'),
            Arel.sql('MAX(ARRAY_LENGTH(concept_paths.full_path_ids, 1))')
          )
          .to_h { |id, concept_count, depth| [id, { concept_count:, depth: }] }
      end

      # Things with at least one assignment from the tree, counted in the mount's result space --
      # the same scope in which facet_values counts its thing_counts per concept. Counted
      # instance-wide instead of scoped, the total would be larger than the sum of the values
      # beneath it, and a client would have to take the difference for a filter error.
      #
      # Correlated Thing query from Mcp::ThingScope -- the same one Mcp::EndpointFacets uses to
      # decide WHICH trees get listed.
      #
      # nil (not 0) without a base_query: 0 would be the statement "this tree carries no contents
      # here" -- a finding that precisely does not follow from a missing result space.
      def thing_counts
        return if @base_query.nil?

        @thing_counts ||= DataCycleCore::CollectedConceptContent
          .where(concept_scheme_id: @scheme_ids)
          .where(DataCycleCore::Mcp::ThingScope.correlated_to_classification(@base_query.query).arel.exists)
          .group(:concept_scheme_id)
          .distinct
          .count(:thing_id)
      end
    end
  end
end
