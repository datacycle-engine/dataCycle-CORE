# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sortable
      def reset_sort
        reflect(
          @query.except(:order)
        )
      end

      def sort_random(_ordering)
        reflect(
          @query
            .order(Arel.sql(ActiveRecord::Base.send(:sanitize_sql_for_order, 'random()')))
        )
      end

      def sort_boost(ordering)
        reflect(
          @query
            .order(sanitized_order_string('things.boost', ordering))
        )
      end

      def sort_updated_at(ordering)
        reflect(
          @query
            .order(sanitized_order_string('things.updated_at', ordering))
        )
      end
      alias sort_dct_modified sort_updated_at

      def sort_created_at(ordering)
        reflect(
          @query
            .order(sanitized_order_string('things.created_at', ordering))
        )
      end
      alias sort_dct_created sort_created_at

      def sort_translated_name(ordering)
        locale = @locale&.first || I18n.available_locales.first.to_s
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT JOIN thing_translations ON thing_translations.thing_id = things.id AND thing_translations.locale = ?', locale]))
            .order(sanitized_order_string('thing_translations.name', ordering, true))
        )
      end
      alias sort_name sort_translated_name

      # TODO: respect date for sorting
      def sort_by_proximity(_ordering = '', _value = {})
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
        return self if value.blank?
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
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ?', locale]))
            .reorder(
              Arel.sql(sanitized_order_string(order_string, ordering, true)),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id DESC')
            )
        )
      end

      def sort_fulltext_search_with_cte(ordering)
        reflect(
          @query
            .reorder(
              Arel.sql(sanitized_order_string('fulltext_boost', ordering, true)),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id DESC')
            )
        )
      end

      def sanitized_order_string(order_string, order, nulls_last = false)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for ordering: #{order}" unless ['ASC', 'DESC'].include?(order)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for order string: #{order_string}" if order_string.blank?

        order_nulls = nulls_last ? ' NULLS LAST' : ''
        ActiveRecord::Base.send(:sanitize_sql_for_order, "#{order_string} #{order}#{order_nulls}")
      end
    end
  end
end
