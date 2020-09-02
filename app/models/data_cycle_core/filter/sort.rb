# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sort
      def reset_sort
        reflect(
          @query.except(:order)
        )
      end
      def sort_boost(ordering)
        return self if ordering.blank?
        reflect(
          @query
            .order(Arel.sql("things.boost #{ordering}"))
        )
      end

      def sort_updated_at(ordering)
        return self if ordering.blank?
        reflect(
          @query
            .order(Arel.sql("things.created_at #{ordering}"))
        )
      end

      def sort_created_at(ordering)
        return self if ordering.blank?
        reflect(
          @query
            .order(Arel.sql("things.updated_at #{ordering}"))
        )
      end

      def sort_translated_name(ordering)
        return self if ordering.blank? || @locale.blank?
        reflect(
          @query
            .joins("LEFT JOIN thing_translations ON thing_translations.thing_id = things.id AND thing_translations.locale = '#{@locale.first}'")
            .order(
              Arel.sql("thing_translations.name #{ordering} NULLS LAST")
            )
        )
      end

      # Todo respect date for sorting
      def sort_by_proximity(_ordering, _value)
        date = Time.zone.now
        # date = date_from_single_value(value) || Time.zone.now
        reflect(
          @query.reorder(
            absolute_date_diff(thing[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
            absolute_date_diff(thing[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
            thing[:start_date]
          )
        )
      end

      def sort_fulltext_search(ordering, value)
        return self if ordering.blank? || value.blank?
        locale = @locale&.first || I18n.available_locales.first.to_s
        search_string = (value || '').split(' ').join('%')

        order_string = ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            Arel.sql(
              "things.boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery('simple', :search),16) +
              1 * similarity(searches.full_text, :search_string))"
            ),
            search_string: "%#{search_string}%",
            search: (value || '').squish
          ]
        )
        reflect(
          @query
            .joins("LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = '#{locale}'")
            .reorder(
              Arel.sql("#{order_string} #{ordering} NULLS LAST"),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id ASC')
            )
        )
      end

      def sort_fulltext_search_with_cte(ordering)
        reflect(
          @query
            .reorder(
              Arel.sql("fulltext_boost #{ordering}"),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id ASC')
            )
        )
      end
    end
  end
end
