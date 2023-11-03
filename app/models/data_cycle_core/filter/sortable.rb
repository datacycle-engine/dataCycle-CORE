# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sortable
      def reset_sort
        reflect(@query.reorder(nil))
      end

      def sort_default(_ordering = 'DESC')
        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string('things.boost', 'DESC'),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_collection_manual_order(ordering, watch_list_id)
        return self if watch_list_id.nil?

        reflect(
          @query
            .joins(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        'LEFT OUTER JOIN watch_list_data_hashes ON watch_list_data_hashes.watch_list_id = ? AND watch_list_data_hashes.hashable_id = things.id',
                                        watch_list_id
                                      ])
            )
            .reorder(nil)
            .order(
              sanitized_order_string('watch_list_data_hashes.order_a', ordering.presence || 'ASC'),
              sanitized_order_string('watch_list_data_hashes.created_at', 'ASC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_random(ordering)
        unless ordering.nil?
          random_seed_sql = <<-SQL.squish
            CROSS JOIN (SELECT :seed_value AS seed_value from setseed(:seed_value)) seed_values
          SQL

          random_join_query = ActiveRecord::Base.send(:sanitize_sql_array, [random_seed_sql, seed_value: ordering])
        end

        # TODO: fix random sorting with moving active query into exists subquery

        reflect(
          @query
            .joins(random_join_query)
            .reorder(nil)
            .order(Arel.sql(ActiveRecord::Base.send(:sanitize_sql_for_order, 'random()')))
        )
      end

      def sort_boost(ordering)
        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string('things.boost', ordering),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_updated_at(ordering)
        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string('things.updated_at', ordering),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end
      alias sort_dct_modified sort_updated_at

      def sort_created_at(ordering)
        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string('things.created_at', ordering),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end
      alias sort_dct_created sort_created_at

      def sort_translated_name(ordering)
        locale = @locale&.first || I18n.available_locales.first.to_s

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = things.id AND thing_translations.locale = ?', locale]))
            .reorder(nil)
            .order(
              sanitized_order_string("thing_translations.content ->> 'name'", ordering, true),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end
      alias sort_name sort_translated_name

      def sort_advanced_attribute(ordering, attribute_path)
        locale = @locale&.first || I18n.available_locales.first.to_s
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT OUTER JOIN searches ON searches.content_data_id = things.id AND searches.locale = ?', locale]))
            .reorder(nil)
            .order(
              sanitized_order_string("searches.advanced_attributes -> '#{attribute_path}'", ordering, true),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_proximity_in_time(_ordering = '', value = {})
        date = Time.zone.now
        if value.present? && value.is_a?(::Hash) && value.dig('q') == 'relative'
          date = relative_to_absolute_date(value.dig('in', 'min')) if value.dig('in', 'min').present?
          date = relative_to_absolute_date(value.dig('v', 'from')) if value.dig('v', 'from', 'n').present?
        elsif value.present? && value.is_a?(::Hash)
          date = date_from_single_value(value.dig('in', 'min')) if value.dig('in', 'min').present?
          date = date_from_single_value(value.dig('v', 'from')) if value.dig('v', 'from').present?
        end
        reflect(
          @query
            .reorder(nil)
            .order(
              absolute_date_diff(cast_ts(in_json(thing[:metadata], 'end_date')), Arel::Nodes.build_quoted(date.iso8601)),
              absolute_date_diff(cast_ts(in_json(thing[:metadata], 'start_date')), Arel::Nodes.build_quoted(date.iso8601)),
              cast_ts(in_json(thing[:metadata], 'start_date')),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_by_proximity(ordering = '', value = {})
        start_date, end_date = date_from_filter_object(value['in'] || value['v'], value['q']) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])

        return self if start_date.nil? && end_date.nil?

        joined_table_name = "schedule_occurrences_#{SecureRandom.hex(10)}"

        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN LATERAL (
          	SELECT thing_id, MIN(LOWER(schedule_occurrences.occurrence)) "min_start_date"
          	FROM schedule_occurrences
          	WHERE things.id = schedule_occurrences.thing_id AND schedule_occurrences.occurrence && TSTZRANGE(?, ?)
          	GROUP BY thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end
      alias sort_by_schedule_proximity sort_by_proximity
      alias sort_proximity_occurrence sort_by_proximity

      def sort_proximity_geographic(ordering = '', value = {})
        return self if value&.first.blank? || value&.second.blank?

        order_string = "things.geom_simple <-> 'SRID=4326;POINT (#{value.first} #{value.second})'::geometry"

        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string(order_string, ordering, true),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_proximity_occurrence_with_distance(ordering = '', value = [])
        proximity_occurrence_with_distance(ordering, value)
      end

      def sort_proximity_in_occurrence_with_distance(ordering = '', value = [])
        proximity_occurrence_with_distance(ordering, value, false)
      end

      def sort_proximity_in_occurrence(ordering = '', value = {})
        proximity_in_occurrence(ordering, value, false)
      end

      def proximity_occurrence_with_distance(ordering = '', value = [], sort_by_date = true, use_spheroid = true)
        return self if !value.is_a?(::Array) || value.first.blank?
        geo = value.first
        schedule = value.second
        return self if geo&.first.blank? || geo&.second.blank?

        if use_spheroid
          geo_order_string = "ST_DISTANCE(things.geom_simple,'SRID=4326;POINT (#{geo.first} #{geo.second})'::geometry,true)"
        else
          geo_order_string = "ST_DISTANCE(things.geom_simple,'SRID=4326;POINT (#{geo.first} #{geo.second})'::geometry)"
        end

        if schedule.present? && schedule.is_a?(::Hash) && (schedule['in'] || schedule['v'])
          start_date, end_date = date_from_filter_object(schedule['in'] || schedule['v'], schedule['q'])
        else
          start_date = Time.zone.now
          end_date = Time.zone.now.end_of_day
        end

        if sort_by_date
          min_start_date = 'MIN(LOWER(schedule_occurrences.occurrence))'
        else
          min_start_date = '1'
        end

        joined_table_name = "schedules_#{SecureRandom.hex(10)}"
        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT
              a.thing_id,
              1 AS "occurrence_exists",
              t.min_start_date
            FROM
              schedules a
            LEFT OUTER JOIN (
              SELECT
                thing_id,
                #{min_start_date} as "min_start_date"
              FROM
                schedule_occurrences
              WHERE
                schedule_occurrences.occurrence && TSTZRANGE(?, ?)
              GROUP BY
                thing_id
            ) as t on t.thing_id = a.thing_id
            WHERE
              things.id = a.thing_id
            GROUP BY
              a.thing_id, t.min_start_date
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string(geo_order_string, ordering, true),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def proximity_in_occurrence(ordering = '', value = {}, sort_by_date = true)
        start_date, end_date = date_from_filter_object(value['in'] || value['v'], value['q']) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])

        if start_date.nil? && end_date.nil?
          start_date = Time.zone.now
          end_date = Time.zone.now.end_of_day
        end
        if sort_by_date
          min_start_date = 'MIN(LOWER(schedule_occurrences.occurrence))'
        else
          min_start_date = '1'
        end

        joined_table_name = "schedules_#{SecureRandom.hex(10)}"
        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT
              a.thing_id,
              1 AS "occurrence_exists",
              t.min_start_date
            FROM
              schedules a
            LEFT OUTER JOIN (
              SELECT
                thing_id,
                #{min_start_date} as "min_start_date"
              FROM
                schedule_occurrences
              WHERE
                schedule_occurrences.occurrence && TSTZRANGE(?, ?)
              GROUP BY
                thing_id
            ) as t on t.thing_id = a.thing_id
            WHERE
              things.id = a.thing_id
            GROUP BY
              a.thing_id, t.min_start_date
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sort_fulltext_search(ordering, value)
        return self if value.blank?
        locale = @locale&.first || I18n.available_locales.first.to_s
        search_string = value.to_s.split.join('%')

        order_string = ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            Arel.sql(
              "things.boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery(COALESCE(pg_dict_mappings.dict, 'pg_catalog.simple')::regconfig, :search),16) +
              1 * similarity(searches.full_text, :search_string))"
            ),
            search_string: "%#{search_string}%",
            search: value.to_s.squish
          ]
        )
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ? LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale', locale]))
            .reorder(nil)
            .order(
              sanitized_order_string(order_string, ordering, true),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      alias sort_similarity sort_fulltext_search

      def sort_fulltext_search_with_cte(ordering)
        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string('fulltext_boost', ordering, true),
              sanitized_order_string('things.updated_at', 'DESC'),
              sanitized_order_string('things.id', 'DESC')
            )
        )
      end

      def sanitized_order_string(order_string, order, nulls_last = false)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for ordering: #{order}" unless ['ASC', 'DESC'].include?(order)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for order string: #{order_string}" if order_string.blank?

        order_nulls = nulls_last ? ' NULLS LAST' : ''
        Arel.sql(ActiveRecord::Base.send(:sanitize_sql_for_order, "#{order_string} #{order}#{order_nulls}"))
      end
    end
  end
end
