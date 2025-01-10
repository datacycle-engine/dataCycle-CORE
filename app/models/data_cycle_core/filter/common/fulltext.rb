# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Fulltext
        def fulltext_search(name)
          return self if name.blank?
          normalized_name = name.unicode_normalize(:nfkc)

          if DataCycleCore.filter_strategy == 'joins'
            search_alias = "se#{SecureRandom.hex(5)}"
            pg_dict_alias = "pgd#{SecureRandom.hex(5)}"
            split_name = normalized_name.split
            matches_all = Array.new(split_name.size, "#{search_alias}.all_text ILIKE ?").join(' AND')
            matches_query = sanitize_sql([matches_all, *split_name.map { |item| "%#{item.strip}%" }])
            joins_query = [
              "INNER JOIN searches #{search_alias} ON #{search_alias}.content_data_id = #{thing_alias.right}.id"
            ]

            if @locale.present?
              joins_query[0] += " AND #{search_alias}.locale IN (?)"
              joins_query << @locale
            end

            joins_query[0] += "INNER JOIN pg_dict_mappings #{pg_dict_alias} ON #{pg_dict_alias}.locale = #{search_alias}.locale"

            reflect(
              @query
                .joins(sanitize_sql(joins_query))
                .where("#{matches_query} AND #{search_alias}.words @@ plainto_tsquery(#{pg_dict_alias}.dict, ?)", normalized_name.squish)
            )
          else
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
        end

        def ts_query_fulltext_search(name)
          return self if name.blank?

          q = text_to_websearch_tsquery(name)

          if DataCycleCore.filter_strategy == 'joins'
            search_alias = "se#{SecureRandom.hex(5)}"
            pg_dict_alias = "pgd#{SecureRandom.hex(5)}"
            joins_query = [
              "INNER JOIN searches #{search_alias} ON #{search_alias}.content_data_id = #{thing_alias.right}.id"
            ]

            if @locale.present?
              joins_query[0] += " AND #{search_alias}.locale IN (?)"
              joins_query << @locale
            end

            joins_query[0] += "INNER JOIN pg_dict_mappings #{pg_dict_alias} ON #{pg_dict_alias}.locale = #{search_alias}.locale"

            reflect(
              @query
                .joins(sanitize_sql(joins_query))
                .where("#{search_alias}.search_vector @@ websearch_to_prefix_tsquery(#{pg_dict_alias}.dict, ?)", q)
            )
          else

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
        end

        alias fulltext_search ts_query_fulltext_search if Feature::TsQueryFulltextSearch.enabled?
      end
    end
  end
end
