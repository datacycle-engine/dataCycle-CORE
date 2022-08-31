# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sortable
      def reset_sort
        reflect(
          @query.except(:order)
        )
      end

      def sort_random(ordering)
        unless ordering.nil?
          random_seed_sql = <<-SQL.squish
            CROSS JOIN (SELECT :seed_value AS seed_value from setseed(:seed_value)) seed_values
          SQL

          random_join_query = ActiveRecord::Base.send(:sanitize_sql_array, [random_seed_sql, seed_value: ordering])
        end

        reflect(
          @query
            .joins(random_join_query)
            .order(Arel.sql(ActiveRecord::Base.send(:sanitize_sql_for_order, 'random()')))
        )
      end

      def sort_boost(ordering)
        reflect(
          @query
            .order(
              sanitized_order_string('things.boost', ordering),
              thing[:id].desc
            )
        )
      end

      def sort_updated_at(ordering)
        reflect(
          @query
            .order(
              sanitized_order_string('things.updated_at', ordering),
              thing[:id].desc
            )
        )
      end
      alias sort_dct_modified sort_updated_at

      def sort_created_at(ordering)
        reflect(
          @query
            .order(
              sanitized_order_string('things.created_at', ordering),
              thing[:id].desc
            )
        )
      end
      alias sort_dct_created sort_created_at

      def sort_translated_name(ordering)
        locale = @locale&.first || I18n.available_locales.first.to_s
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT JOIN thing_translations ON thing_translations.thing_id = things.id AND thing_translations.locale = ?', locale]))
            .order(
              sanitized_order_string('thing_translations.name', ordering, true),
              thing[:id].desc
            )
        )
      end
      alias sort_name sort_translated_name

      def sort_advanced_attribute(ordering, attribute_path)
        locale = @locale&.first || I18n.available_locales.first.to_s
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ?', locale]))
            .order(
              Arel.sql(sanitized_order_string("searches.advanced_attributes -> '#{attribute_path}'", ordering, true)),
              thing[:id].desc
            )
        )
      end

      def sort_by_proximity(_ordering = '', value = {})
        date = Time.zone.now
        if value.present? && value.is_a?(::Hash) && value.dig('q') == 'relative'
          date = relative_to_absolute_date(value.dig('in', 'min')) if value.dig('in', 'min').present?
          date = relative_to_absolute_date(value.dig('v', 'from')) if value.dig('v', 'from', 'n').present?
        elsif value.present? && value.is_a?(::Hash)
          date = date_from_single_value(value.dig('in', 'min')) if value.dig('in', 'min').present?
          date = date_from_single_value(value.dig('v', 'from')) if value.dig('v', 'from').present?
        end
        reflect(
          @query.reorder(
            absolute_date_diff(thing[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
            absolute_date_diff(thing[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
            thing[:start_date],
            thing[:id].desc
          )
        )
      end
      alias sort_proximity_intime sort_by_proximity

      def sort_proximity_geographic(ordering = '', value = {})
        return self if value&.first.blank? || value&.second.blank?
        order_string = "things.location <-> 'SRID=4326;POINT (#{value.first} #{value.second})'::geometry"
        reflect(
          @query.reorder(
            Arel.sql(sanitized_order_string(order_string, ordering, true)),
            Arel.sql('things.updated_at DESC'),
            Arel.sql('things.id DESC')
          )
        )
      end

      def sort_by_schedule_proximity(ordering = '', value = {})
        start_date, end_date = date_from_filter_object(value['in'] || value['v'], value.dig('q')) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])

        return self if start_date.nil? && end_date.nil?

        joined_table_name = "schedule_occurrences_#{SecureRandom.hex(10)}"

        order_parameter_join = <<-SQL.squish
          JOIN LATERAL (
          	SELECT thing_id, MIN(LOWER(schedule_occurrences.occurrence)) "min_start_date"
          	FROM schedule_occurrences
          	WHERE things.id = schedule_occurrences.thing_id AND schedule_occurrences.occurrence && TSTZRANGE(?, ?)
          	GROUP BY thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(
              Arel.sql(sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true)),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id DESC')
            )
        )
      end
      alias sort_proximity_occurrence sort_by_schedule_proximity

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
              2 * ts_rank_cd(searches.words, plainto_tsquery(pg_dict_mappings.dict::regconfig, :search),16) +
              1 * similarity(searches.full_text, :search_string))"
            ),
            search_string: "%#{search_string}%",
            search: (value || '').squish
          ]
        )
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ? LEFT JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale', locale]))
            .reorder(
              Arel.sql(sanitized_order_string(order_string, ordering, true)),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id DESC')
            )
        )
      end

      alias sort_similarity sort_fulltext_search

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
