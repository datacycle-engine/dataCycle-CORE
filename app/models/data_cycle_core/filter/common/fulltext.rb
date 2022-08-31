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
                  search[:all_text].matches_all(normalized_name.split(' ').map { |item| "%#{item.strip}%" })
                    .or(tsmatch(search[:words], tsquery(quoted(normalized_name.squish), Arel.sql('pg_dict_mappings.dict::regconfig')))),
                  true
                )
              )
          )
        end

        # @todo: Fulltext search with cte for experimental queries
        def fulltext_search_with_cte(name)
          return self if name.blank?
          normalized_name = name.unicode_normalize(:nfkc)

          search_cte = fulltext_search_cte(normalized_name, name)
          joined_search_cte = joins_fulltext_search_cte(search_cte)

          reflect(
            @query
              .joins(joined_search_cte)
          )
        end

        def joins_fulltext_search_cte(search_cte)
          <<-SQL
          JOIN (
            #{search_cte}
            SELECT content_data_id, fulltext_boost FROM cte_search
          )AS joined_search_cte
          ON joined_search_cte.content_data_id = things.id
          SQL
        end

        def fulltext_search_cte(normalized_name, name)
          search_string = (name || '').split(' ').join('%')
          order_string = ActiveRecord::Base.send(
            :sanitize_sql_array,
            [
              Arel.sql(
                "boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery(get_dict(searches.locale), :search),16) +
              1 * similarity(searches.full_text, :search_string))"
              ),
              search_string: "%#{search_string}%",
              search: (name || '').squish
            ]
          )

          if @locale.present?
            res_query = <<-SQL
            WITH cte_search AS (
              SELECT DISTINCT ON (content_data_id)
                content_data_id,
                (#{order_string}) as fulltext_boost
              FROM
                "searches"
              JOIN (SELECT get_dict(searches.locale) AS config, searches.locale AS locale FROM searches GROUP BY searches.locale) as subquery ON subquery.locale = searches.locale
              WHERE
                #{search[:locale].in(@locale).to_sql}
                AND (
                  #{search[:all_text].matches_all(normalized_name.split(' ').map { |item| "%#{item.strip}%" }).to_sql}
                  OR #{tsmatch(search[:words], tsquery(quoted(normalized_name.squish), Arel.sql('subquery.config'))).to_sql}
                )
              ORDER BY
                content_data_id, fulltext_boost DESC
            )
            SQL
          else
            res_query = <<-SQL
            WITH cte_search AS (
              SELECT DISTINCT ON (content_data_id)
                content_data_id,
                (#{order_string}) as fulltext_boost
              FROM
                "searches"
              JOIN (SELECT get_dict(searches.locale) AS config, searches.locale AS locale FROM searches GROUP BY searches.locale) as subquery ON subquery.locale = searches.locale
              WHERE
                  #{search[:all_text].matches_all(normalized_name.split(' ').map { |item| "%#{item.strip}%" }).to_sql}
                  OR #{tsmatch(search[:words], tsquery(quoted(normalized_name.squish), Arel.sql('subquery.config'))).to_sql}
              ORDER BY
                content_data_id, fulltext_boost DESC
            )
            SQL
          end
          res_query
        end
      end
    end
  end
end
