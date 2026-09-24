# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Lists the attributes configured as advanced_search in the endpoint together with their type
      # -- the counterpart to list_facets for search_contents' attributes filter. Without this
      # discovery a client cannot know any valid attribute names or types for structured filters.
      class ListAttributes < Base
        self.tool_name = 'list_attributes'

        input_schema do
          { type: 'object', properties: {} }
        end

        # Returns the endpoint's filterable advanced_search attributes as { attributes: [...] }.
        # arguments stays unused: the tool takes no parameters (an empty input_schema).
        def call(arguments:, context:) # rubocop:disable Lint/UnusedMethodArgument -- fixed Tool#call interface (Publication#to_mcp_tool)
          attributes = DataCycleCore::Mcp::AttributeFilter.new.available(scope_template_names(context))

          { attributes: }
        end
      end
    end
  end
end
