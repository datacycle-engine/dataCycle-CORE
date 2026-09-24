# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Lists the content templates (schema.org types) occurring in the endpoint together with their
      # counts -- the discovery for search_contents' template_names filter, analogous to
      # list_facets/facet_values for classifications and list_attributes for attributes.
      #
      # Without this list the type of a content is a blind guess: a client asked for "restaurants
      # (FoodEstablishment)" cannot see that the endpoint does not carry that template at all and
      # that gastronomy is modelled here as TouristAttraction plus a category. The count beside it
      # makes exactly that visible (FoodEstablishment is missing from the list, TouristAttraction has
      # thousands) instead of leaving it a silent false assumption.
      class ListTemplates < Base
        self.tool_name = 'list_templates'

        input_schema do
          { type: 'object', properties: {} }
        end

        # Returns the endpoint's templates as { templates: [{ template_name:, count: }] }.
        # The counting lives in Mcp::TemplateCounts, because describe_endpoint carries the same list
        # as part of its profile -- two formulations would give the same client two lists.
        #
        # arguments stays unused: the tool takes no parameters (an empty input_schema).
        def call(arguments:, context:) # rubocop:disable Lint/UnusedMethodArgument -- fixed Tool#call interface (Publication#to_mcp_tool)
          { templates: DataCycleCore::Mcp::TemplateCounts.call(context[:base_query]) }
        end
      end
    end
  end
end
