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

        def sorting_string
          sorting_array = []

          sort_config.each do |config|
            sorting = [SORT_BASE]
            sorting.unshift("'#{config[:weights].to_pg_array}'") if config[:weights].present?
            sorting << config[:normalization] if config[:normalization].present?
            sorting_array << "ts_rank_cd(#{sorting.join(', ')})"
          end

          sorting_array.join(' + ')
        end
      end
    end
  end
end
