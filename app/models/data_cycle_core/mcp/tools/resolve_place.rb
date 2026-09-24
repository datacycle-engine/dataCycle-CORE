# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Resolves a place name and reports which stages of the geo cascade take effect for it -- the
      # discovery for search_contents' place filter.
      #
      # The tool deliberately takes ONLY a name: the resolution strategy (classification tree ->
      # geo_regions -> address) lives in Mcp::GeoScope::STAGES and is not a parameter. That way an
      # LLM cannot choose, reorder or skip it -- the reason this tool exists at all instead of an
      # instruction in a tool description.
      class ResolvePlace < Base
        self.tool_name = 'resolve_place'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              place: { type: 'string', description: argument_description('place', locale:) }
            },
            required: ['place']
          }
        end

        # @return [Hash] descriptor of the resolved place together with the hit count per cascade
        #   stage, or an error hash when the name occurs in no configured tree.
        def call(arguments:, context:)
          scope = DataCycleCore::Mcp::GeoScope.resolve(arguments[:place])

          return unresolved(arguments[:place]) if scope.nil?

          # compact: without a base_query (the global server) there are no per-stage hit counts --
          # the field is then absent rather than reading as a measured zero via "coverage: null".
          scope.to_h.merge(coverage: coverage(scope, context)).compact
        end

        private

        # The hit count per stage INSIDE the endpoint -- without those numbers there is no way to
        # tell whether a result is carried by the classification tree or mostly by the weaker address
        # comparison.
        def coverage(scope, context)
          base = context[:base_query]
          return nil if base.nil?

          scope.coverage(base)
        end

        def unresolved(place)
          {
            place:,
            resolved: false,
            error: DataCycleCore::Mcp::Translations.t('errors.unresolved_place', place:),
            searched_concept_schemes: DataCycleCore::Feature::Mcp.resolution_trees
          }
        end
      end
    end
  end
end
