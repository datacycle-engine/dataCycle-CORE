# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Fulltext
        def fulltext_search(name)
          return self if name.blank?
          normalized_name = name.unicode_normalize(:nfkc)
          subquery = DataCycleCore::Search.select(1)
          subquery = subquery.where(locale: @locale) if @locale.present?
          subquery = subquery.left_outer_joins(:pg_dict_mapping)
          subquery = subquery.where(search[:content_data_id].eq(thing[:id]))
          all_matches = normalized_name.split.map { |item| "%#{item.strip}%" }
          subquery = subquery.where(search[:all_text].matches_all(all_matches))
            .or(subquery.where(tsmatch(search[:words], tsquery(quoted(normalized_name.squish), pg_dict_mapping[:dict]))))

          reflect(@query.where(subquery.arel.exists))
        end

        def ts_query_fulltext_search(name)
          return self if name.blank?

          q = text_to_websearch_tsquery(name)
          subquery = DataCycleCore::Search.select(1)
          subquery = subquery.where(locale: @locale) if @locale.present?
          subquery = subquery.left_outer_joins(:pg_dict_mapping)
          subquery = subquery.where(search[:content_data_id].eq(thing[:id]))
          subquery = subquery.where(tsmatch(search[:search_vector], websearch_to_prefix_tsquery(q, pg_dict_mapping[:dict])))

          reflect(@query.where(subquery.arel.exists))
        end

        alias fulltext_search ts_query_fulltext_search if Feature::TsQueryFulltextSearch.enabled?
      end
    end
  end
end
