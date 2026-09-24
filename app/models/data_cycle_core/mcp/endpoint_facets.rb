# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The concept schemes (classification trees) of an endpoint -- one definition for every tool
    # that needs "the facets of this endpoint" (list_facets, resolve_concepts). A second, diverging
    # selection would not be explainable to a client: resolve_concepts would propose concepts from
    # trees list_facets does not name (or conversely withhold some).
    #
    # When facets are configured explicitly on the endpoint (concept_schemes), exactly those apply
    # (a curated selection). Where the curation is missing -- or where there is no endpoint at all,
    # as on the global mount -- the API-visible trees actually occurring in the result space are
    # derived instead.
    module EndpointFacets
      class << self
        # @param context [Hash] the server context of a tool (:stored_filter, :base_query);
        #   :stored_filter is absent on the global mount, where the derived branch always applies.
        # @return [ActiveRecord::Relation<ConceptScheme>]
        def scope(context)
          configured = context[:stored_filter]&.concept_scheme_ids
          return DataCycleCore::ConceptScheme.where(id: configured).order(:name) if configured.present?

          DataCycleCore::ConceptScheme
            .where(internal: false)
            .visible('api')
            .where(present_in_endpoint(context[:base_query].query))
            .order(:name)
        end

        private

        # Arel EXISTS: the tree occurs in at least one content of the endpoint. The correlated Thing
        # query comes from Mcp::ThingScope -- the same one Mcp::ConceptSchemeMetrics counts the
        # thing_count per tree with, so that "is listed" and "carries N contents" mean the same
        # result space.
        def present_in_endpoint(query)
          DataCycleCore::CollectedConceptContent
            .where('collected_concept_contents.concept_scheme_id = concept_schemes.id')
            .where(DataCycleCore::Mcp::ThingScope.correlated_to_classification(query).arel.exists)
            .arel.exists
        end
      end
    end
  end
end
