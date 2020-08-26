# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sort
      def sort_boost(table, value)
        return self if table.blank? || value.blank?
        reflect(
          @query
            .order(Arel.sql("#{table}.boost #{value}"))
        )
      end

      def sort_updated_at(table, value)
        return self if table.blank? || value.blank?
        reflect(
          @query
            .order(Arel.sql("#{table}.updated_at #{value}"))
        )
      end

      def sort_ful2ltext_search(_table, _value)
        search_string = (search || '').split(' ').join('%')

        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            Arel.sql(
              "things.boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery('simple', :search),16) +
              1 * similarity(searches.full_text, :search_string))
              DESC NULLS LAST,
              things.updated_at DESC"
            ),
            search_string: "%#{search_string}%",
            search: (search || '').squish
          ]
        )
      end
    end
  end
end
