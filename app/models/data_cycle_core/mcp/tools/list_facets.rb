# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Lists the facets (ConceptSchemes) of the endpoint scoped by stored_filter -- the
      # entry point before facet_values needs an id. Which trees those are is decided by
      # Mcp::EndpointFacets (curated or derived from the results) -- shared with resolve_concepts so
      # that both tools see the same section.
      class ListFacets < Base
        self.tool_name = 'list_facets'
        input_schema { { type: 'object', properties: {} } }

        # arguments stays unused: the tool takes no parameters (an empty input_schema).
        # describe_schemes (instead of {id:, name:}) adds the measured metrics and the curated
        # definition from config/locales/{de,en}.mcp.yml -- without them a client sees only the tree
        # name and has to guess the dimension, see Base#describe_scheme. The same representation as
        # in browse_concept_schemes and facet_values.
        #
        # Plus classification_tree_label_id, because exactly that value is passed on to facet_values
        # under that same parameter name (which comes from the OpenAPI route
        # /endpoints/{id}/facets/{classification_tree_label_id} and is therefore not freely
        # choosable). A bare "id" beside a tool demanding "classification_tree_label_id" reads like
        # two different identifiers -- it is the same one. id is additionally kept so existing
        # clients do not break.
        def call(arguments:, context:) # rubocop:disable Lint/UnusedMethodArgument -- fixed Tool#call interface (Publication#to_mcp_tool)
          schemes = describe_schemes(DataCycleCore::Mcp::EndpointFacets.scope(context), context)
            .map { |scheme| { classification_tree_label_id: scheme[:id] }.merge(scheme) }

          { schemes: }
        end
      end
    end
  end
end
