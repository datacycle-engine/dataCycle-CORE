# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The templates occurring in the result space together with their counts -- one formulation for
    # Tools::ListTemplates and Mcp::EndpointProfile, which answer the same question.
    #
    # Written out twice they would drift apart at the next change (ordering, result space), and a
    # client would get a different list for the same question depending on the tool -- the same
    # argument as Mcp::EndpointFacets makes for the facets.
    module TemplateCounts
      module_function

      # Descending by count: the endpoint's load-bearing types come first, relation targets with a
      # handful of contents last. Ties break by name so the order is stable.
      #
      # @param base_query [DataCycleCore::Filter::Search] result space of the mount
      # @return [Array<Hash>] [{ template_name:, count: }], descending by count
      def call(base_query)
        base_query
          .query
          .reorder(nil)
          .group(:template_name)
          .count
          .sort_by { |template_name, count| [-count, template_name.to_s] }
          .map { |template_name, count| { template_name:, count: } }
      end
    end
  end
end
