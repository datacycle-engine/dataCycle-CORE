# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The result space of a mount as a CORRELATED subquery, joinable to a
    # collected_concept_contents row: "does this content belong to the endpoint, or to the
    # user's api visibility scope?".
    #
    # One place for everyone who needs it (Mcp::EndpointFacets for "does this tree occur here at
    # all", Mcp::ConceptSchemeMetrics for "how many contents carry it here"). Written out twice, the
    # two would drift apart at the next change to base_query -- and a facet that list_facets names
    # but describes with thing_count 0 is not explainable to a client.
    module ThingScope
      module_function

      # @param query [ActiveRecord::Relation<Thing>] base_query of the mount (endpoint or ApiScope)
      # @return [ActiveRecord::Relation] SELECT 1, correlated to collected_concept_contents
      #   -- for .arel.exists at the caller.
      #
      # except(UNION_FILTER_EXCEPTS): the union clauses make the query unusable as a subquery;
      # Concept.thing_counts_for_tree performs the same cleanup.
      def correlated_to_classification(query)
        query
          .where('things.id = collected_concept_contents.thing_id')
          .except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS)
          .select(1)
      end
    end
  end
end
