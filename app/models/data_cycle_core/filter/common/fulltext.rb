# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Fulltext
        def fulltext_search(name)
          return self if name.blank?
          normalized_name = name.unicode_normalize(:nfkc)

          reflect(
            @query
              .where(
                search_exists(
                  search[:all_text].matches_all(normalized_name.split.map { |item| "%#{item.strip}%" })
                    .or(tsmatch(search[:words], tsquery(quoted(normalized_name.squish), pg_dict_mapping[:dict]))),
                  true
                )
              )
          )
        end

        def ts_query_fulltext_search(name)
          return self if name.blank?

          q = text_to_websearch_tsquery(name)

          reflect(
            @query
              .where(
                search_exists(
                  tsmatch(search[:search_vector], websearch_to_prefix_tsquery(q, pg_dict_mapping[:dict])),
                  true
                )
              )
          )
        end

        alias fulltext_search ts_query_fulltext_search if Feature::TsQueryFulltextSearch.enabled?
      end
    end
  end
end
