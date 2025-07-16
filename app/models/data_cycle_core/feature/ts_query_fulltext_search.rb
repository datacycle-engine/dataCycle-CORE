# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TsQueryFulltextSearch < Base
      SORT_ALGORITHM = 'ts_rank_cd'
      SORT_BASE = 'searches.search_vector, websearch_to_prefix_tsquery(pg_dict_mappings.dict, :q)'

      class << self
        def sort_config
          Array.wrap(configuration[:sorting]).compact_blank
        end

        def sort_array
          sorting_array = []

          sort_config.each do |config|
            sorting = [SORT_BASE]
            parameters = {}
            if config[:weights].is_a?(Array) && config[:weights].present?
              sorting.unshift(':weights')
              parameters[:weights] = config[:weights].to_pg_array
            end

            if config[:normalization].present?
              sorting << ':normalization'
              parameters[:normalization] = config[:normalization]
            end

            sorting_array << {
              sorting: sorting.join(', '),
              parameters:
            }
          end

          sorting_array
        end
      end
    end
  end
end
