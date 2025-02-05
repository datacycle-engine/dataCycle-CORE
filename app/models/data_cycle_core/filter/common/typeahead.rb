# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Typeahead
        def typeahead(typeahead_text, language = ['de'], limit = 10)
          return [] if typeahead_text.blank?
          normalized_search = typeahead_text.unicode_normalize(:nfkc)
          locale = language.first # typeahead only supports one language!
          typeahead_query = <<-SQL.squish
            SELECT word, word <-> :word as score
            FROM ts_stat($$
              #{
                @query
                  .except(:order)
                  .joins(:searches)
                  .where(searches: { locale: locale })
                  .select('searches.words_typeahead')
                  .to_sql
              }
            $$)
            ORDER BY score
            LIMIT :limit
          SQL

          ActiveRecord::Base.connection.select_all(
            sanitize_sql([typeahead_query, {word: normalized_search, limit:}])
          )
        end

        def typeahead_by_title(typeahead_text, language = ['de'], limit = 10)
          return [] if typeahead_text.blank?

          normalized_name = typeahead_text.unicode_normalize(:nfkc).strip
          locale = language.first # typeahead only supports one language!

          typeahead_query = <<-SQL.squish
            SELECT s1.headline
            FROM searches s1
              INNER JOIN (
                SELECT DISTINCT ON (TRIM(s.headline)) s.id,
                  word_similarity(s.headline, :sort) AS rank
                FROM searches s
                WHERE s.headline ILIKE :search
                  AND s.locale = :locale
                  AND s.content_data_id IN (#{@query.reorder(nil).select(:id).to_sql})
                LIMIT :limit
              ) s2 ON s2.id = s1.id
            ORDER BY s2.rank DESC NULLS LAST
          SQL

          ActiveRecord::Base.connection.select_all(
            sanitize_sql([
                           typeahead_query,
                           {search: "#{normalized_name}%",
                            sort: normalized_name,
                            locale:,
                            limit:}
                         ])
          ).to_a.pluck('headline').map(&:strip)
        end

        # not working in special cases, as text_to_tsquery does not parse everything correctly
        # possible weights: A, B, C, D
        # A: name (headline)
        # B: slug
        # C: classifications
        # D: all indexed attributes
        def typeahead_by_weight(typeahead_text, language = ['de'], limit = 10, weights = nil)
          return [] if typeahead_text.blank?

          normalized_name = text_to_tsquery(typeahead_text, '<->', weights)
          normalized_name += normalized_name.match?(/:[ABCD]{0,4}$/i) ? '*' : ':*'
          locale = language.first # typeahead only supports one language!

          typeahead_query = <<-SQL.squish
            SELECT s1.headline
            FROM searches s1
              INNER JOIN (
                SELECT DISTINCT ON (s.headline) s.id,
                  ts_rank_cd(
                    s.search_vector,
                    to_tsquery(pg_dict_mappings.dict, :tsquery_value),
                    2
                  ) AS rank
                FROM searches s
                  LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = s.locale
                WHERE s.search_vector @@ to_tsquery(
                    "pg_dict_mappings"."dict",
                    :tsquery_value
                  )
                  AND s.locale = :locale
                  AND s.content_data_id IN (#{@query.reorder(nil).select(:id).to_sql})
                LIMIT :limit
              ) s2 ON s2.id = s1.id
            ORDER BY s2.rank DESC NULLS LAST
          SQL

          ActiveRecord::Base.connection.select_all(
            sanitize_sql([
                           typeahead_query,
                           {tsquery_value: normalized_name,
                            locale:,
                            limit:}
                         ])
          ).to_a.pluck('headline').map(&:strip)
        end
      end
    end
  end
end
