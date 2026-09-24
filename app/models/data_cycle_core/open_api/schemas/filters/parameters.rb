# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module Filters
        # The GET `filter` query parameter (bracket notation) and its Swagger UI
        # examples. Extended into Filters so its methods are available as
        # Filters.* module methods (mirrors Localizable).
        module Parameters
          # @return [Hash{String=>Hash}] parameters for components/parameters
          #   (the GET bracket-notation representation of the filter).
          def parameters
            { 'filter' => filter_param }
          end

          # `filter` query parameter (bracket notation, e.g.
          # `filter[dc:classification][in][withSubtree]=UUID`).
          def filter_param
            {
              'name' => 'filter',
              'in' => 'query',
              'required' => false,
              'style' => 'deepObject',
              'explode' => true,
              'description' => t('filter.param'),
              'schema' => { '$ref' => DataCycleCore::OpenApi::Schemas::Filters::FILTER_REF }
            }
          end
        end
      end
    end
  end
end
