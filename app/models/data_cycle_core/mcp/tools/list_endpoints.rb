# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Endpoint discovery -- closes the same REST gap as list_facets (there is no GET
      # /api/v4/endpoints), here straight through the model layer rather than through a new REST
      # endpoint (see #4 "tool candidates" of the story). The same scope as
      # Api::V4::UsersController#index
      # (DataCycleCore::StoredFilter.accessible_by(current_ability, :api).named).
      class ListEndpoints < Base
        self.tool_name = 'list_endpoints'
        input_schema { { type: 'object', properties: {} } }

        # arguments stays unused: the tool takes no parameters (an empty input_schema).
        #
        # includes(:concept_schemes): the curation is needed for EVERY listed endpoint, and loaded
        # one by one it would be an N+1 on the discovery path. This way it stays at two queries, no
        # matter how many endpoints the user is allowed to see.
        def call(arguments:, context:) # rubocop:disable Lint/UnusedMethodArgument -- fixed Tool#call interface (Publication#to_mcp_tool)
          endpoints = DataCycleCore::StoredFilter
            .accessible_by(context[:ability], :api)
            .named
            .includes(:concept_schemes)

          { endpoints: endpoints.map { |endpoint| describe_endpoint(endpoint) } }
        end

        private

        # Until now this tool returned only id and name. A client landing on the global mount had to
        # guess its endpoint from the name -- and a name like "Touren" does not say whether
        # accommodations sit there too, which language it is maintained in, or which dimensions it
        # can be filtered on. The guess is not recognisably wrong: the client picks a plausible
        # endpoint, gets a plausible number and reports it without reservation.
        #
        # Empty fields are omitted rather than carried empty (compact), so "not maintained" stays
        # distinguishable from "maintained and empty" -- the same convention as for the curated tree
        # definition in Tools::Base#describe_scheme.
        #
        # NOT included: the content volume and the templates occurring in it. Both can only be
        # answered by RUNNING the respective filter, i.e. one query per listed endpoint on a call
        # that is deliberately the cheap entry point. At the endpoint itself, list_templates and
        # search_contents without a filter answer the same question exactly.
        def describe_endpoint(endpoint)
          {
            id: endpoint.id,
            name: endpoint.name,
            # description_stripped rather than description: the editorial description is maintained
            # as HTML in the backend, and markup in the description text is only noise to a client.
            description: endpoint.description_stripped.presence,
            language: endpoint.language.presence,
            # The facet curation CONFIGURED on the endpoint. A missing key does NOT mean "no
            # facets": Mcp::EndpointFacets then derives them from the trees actually occurring
            # there. The tool description names exactly that distinction.
            concept_schemes: endpoint.concept_schemes.map { |scheme| { id: scheme.id, name: scheme.name } }.presence
          }.compact
        end
      end
    end
  end
end
