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
              thing_alias[:boost].desc,
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      def sort_collection_manual_order(ordering, watch_list_id)
        return self if watch_list_id.nil?

        reflect(
          @query
            .joins(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        "LEFT OUTER JOIN watch_list_data_hashes ON watch_list_data_hashes.watch_list_id = ? AND watch_list_data_hashes.thing_id = #{thing_alias.right}.id",
                                        watch_list_id
                                      ])
            )
            .reorder(nil)
            .order(
              watch_list_data_hash[:order_a].send(sanitized_ordering(ordering.presence || 'asc')),
              watch_list_data_hash[:created_at].asc,
              thing_alias[:id].desc
            )
        )
      end

      def sort_random(_ordering = nil, seed = nil)
        unless seed.nil?
          random_seed_sql = <<-SQL.squish
            CROSS JOIN (SELECT :seed_value AS seed_value from setseed(:seed_value)) seed_values
          SQL

          random_join_query = ActiveRecord::Base.send(:sanitize_sql_array, [random_seed_sql, {seed_value: seed}])
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
              thing_alias[:boost].send(sanitized_ordering(ordering)),
              thing_alias[:id].desc
            )
        )
      end

      def sort_updated_at(ordering)
        reflect(
          @query
            .reorder(nil)
            .order(
              thing_alias[:updated_at].send(sanitized_ordering(ordering)),
              thing_alias[:id].desc
            )
        )
      end
      alias sort_dct_modified sort_updated_at

      def sort_created_at(ordering)
        reflect(
          @query
            .reorder(nil)
            .order(
              thing_alias[:created_at].send(sanitized_ordering(ordering)),
              thing_alias[:id].desc
            )
        )
      end
      alias sort_dct_created sort_created_at

      def sort_translated_name(ordering)
        locale = @locale&.first || I18n.available_locales.first.to_s

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = #{thing_alias.right}.id AND thing_translations.locale = ?", locale]))
            .reorder(nil)
            .order(
              sanitized_order_string("thing_translations.content ->> 'name'", ordering, true),
              thing_alias[:id].desc
            )
        )
      end
      alias sort_name sort_translated_name

      def sort_advanced_attribute(ordering, attribute_path)
        locale = @locale&.first || I18n.available_locales.first.to_s
        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["LEFT OUTER JOIN searches ON searches.content_data_id = #{thing_alias.right}.id AND searches.locale = ?", locale]))
            .reorder(nil)
            .order(
              sanitized_order_string("searches.advanced_attributes -> '#{attribute_path}'", ordering, true),
              thing_alias[:id].desc
            )
        )
      end

      def sort_proximity_in_time(_ordering = '', value = {})
        date = Time.zone.now
        if value.present? && value.is_a?(::Hash) && value['q'] == 'relative'
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
              absolute_date_diff(cast_ts(in_json(thing_alias[:metadata], 'end_date')), Arel::Nodes.build_quoted(date.iso8601)),
              absolute_date_diff(cast_ts(in_json(thing_alias[:metadata], 'start_date')), Arel::Nodes.build_quoted(date.iso8601)),
              cast_ts(in_json(thing_alias[:metadata], 'start_date')),
              thing_alias[:id].desc
            )
        )
      end

      def sort_by_proximity(ordering = '', value = {})
        start_date, end_date = date_from_filter_object(value['in'] || value['v'], value['q']) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])

        return self if start_date.nil? && end_date.nil?

        joined_table_name = "schedule_occurrences_#{SecureRandom.hex(10)}"

        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT schedules.thing_id,
              MIN(LOWER(so.occurrence)) AS "min_start_date"
            FROM schedules,
              UNNEST(schedules.occurrences) so(occurrence)
            WHERE #{thing_alias.right}.id = schedules.thing_id
              AND so.occurrence && TSTZRANGE(?, ?)
            GROUP BY schedules.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = #{thing_alias.right}.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end
      alias sort_by_schedule_proximity sort_by_proximity
      alias sort_proximity_occurrence sort_by_proximity

      def sort_proximity_geographic(ordering = '', value = {})
        return self if value&.first.blank? || value&.second.blank?

        order_string = "#{thing_alias.right}.geom_simple <-> 'SRID=4326;POINT (#{value.first} #{value.second})'::geometry"

        reflect(
          @query
            .reorder(nil)
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      def sort_proximity_geographic_with(ordering = '', value = [])
        sort_proximity_geographic(ordering, value)
      end

      def sort_proximity_occurrence_with_distance(ordering = '', value = [])
        proximity_occurrence_with_distance(ordering, value)
      end

      def sort_proximity_in_occurrence_with_distance(ordering = '', value = [])
        proximity_occurrence_with_distance(ordering, value, false)
      end

      def sort_proximity_in_occurrence(ordering = '', value = {})
        proximity_in_occurrence(ordering, value, true)
      end

      def sort_proximity_in_occurrence_pia(ordering = '', value = {})
        proximity_in_occurrence_pia(ordering, value, true)
      end

      def sort_proximity_occurrence_with_distance_pia(ordering = '', value = [])
        proximity_occurrence_with_distance_pia(ordering, value, true)
      end

      def proximity_occurrence_with_distance_pia(ordering = '', value = [], sort_by_date = true, use_spheroid = true)
        return self if !value.is_a?(::Array) || value.first.blank?
        geo = value.first
        schedule = value.second
        return self if geo&.first.blank? || geo&.second.blank?

        if use_spheroid
          geo_order_string = "ST_DISTANCE(#{thing_alias.right}.geom_simple,'SRID=4326;POINT (#{geo.first} #{geo.second})'::geometry,true)"
        else
          geo_order_string = "ST_DISTANCE(#{thing_alias.right}.geom_simple,'SRID=4326;POINT (#{geo.first} #{geo.second})'::geometry)"
        end

        if schedule.present? && schedule.is_a?(::Hash) && (schedule['in'] || schedule['v'])
          start_date, end_date = date_from_filter_object(schedule['in'] || schedule['v'], schedule['q'])
        else
          start_date = Time.zone.now
          end_date = 1.week.from_now.end_of_week
        end

        if sort_by_date
          min_start_date = 'MIN(LOWER(so.occurrence))'
        else
          min_start_date = '1'
        end

        joined_table_name = "schedules_#{SecureRandom.hex(10)}"
        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN (
            SELECT
              a.thing_id,
              1 AS "occurrence_exists",
              #{min_start_date} as "min_start_date"
            FROM
              schedules a,
              UNNEST(a.occurrences) so(occurrence)
            WHERE so.occurrence && TSTZRANGE(?, ?)
            GROUP BY
              a.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = #{thing_alias.right}.id
        SQL

        join_tabel_name2 = "opening_hours_description_closed_#{SecureRandom.hex(10)}"
        order_parameter_join2 = <<-SQL.squish
          LEFT OUTER JOIN (
            SELECT 1 AS "closed_description_exists", cc.content_a_id
            FROM content_contents cc
            LEFT OUTER JOIN classification_contents clc ON clc.content_data_id = cc.content_b_id
            LEFT OUTER JOIN concepts c ON c.id = clc.classification_id  AND c.internal_name = 'geschlossen'
            LEFT OUTER JOIN concept_schemes cs ON cs.id = c.concept_scheme_id  AND cs.name = 'Öffnungszeiten'
            LEFT OUTER JOIN schedules s ON s.thing_id = cc.content_b_id AND s.relation = 'validity_schedule'
            WHERE cc.relation_a = 'opening_hours_description'
            AND s.occurrences && TSTZRANGE(#{"'#{start_date}'"}, #{"'#{start_date.end_of_day}'"})
          ) "#{join_tabel_name2}" ON #{join_tabel_name2}.content_a_id = #{thing_alias.right}.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join2]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string("#{join_tabel_name2}.closed_description_exists", ordering, true),
              sanitized_order_string(geo_order_string, ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      def proximity_occurrence_with_distance(ordering = '', value = [], sort_by_date = true, use_spheroid = true)
        return self if !value.is_a?(::Array) || value.first.blank?
        geo = value.first
        schedule = value.second
        return self if geo&.first.blank? || geo&.second.blank?

        if use_spheroid
          geo_order_string = "ST_DISTANCE(#{thing_alias.right}.geom_simple,'SRID=4326;POINT (#{geo.first} #{geo.second})'::geometry,true)"
        else
          geo_order_string = "ST_DISTANCE(#{thing_alias.right}.geom_simple,'SRID=4326;POINT (#{geo.first} #{geo.second})'::geometry)"
        end

        if schedule.present? && schedule.is_a?(::Hash) && (schedule['in'] || schedule['v'])
          start_date, end_date = date_from_filter_object(schedule['in'] || schedule['v'], schedule['q'])
        else
          start_date = Time.zone.now
          end_date = Time.zone.now.end_of_day
        end

        if sort_by_date
          min_start_date = 'MIN(LOWER(so.occurrence))'
        else
          min_start_date = '1'
        end

        joined_table_name = "schedules_#{SecureRandom.hex(10)}"
        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT a.thing_id,
              1 AS "occurrence_exists",
              CASE WHEN MIN(LOWER(so.occurrence)) IS NULL THEN NULL ELSE #{min_start_date} END as min_start_date
            FROM schedules a
            LEFT OUTER JOIN UNNEST(a.occurrences) so(occurrence) ON so.occurrence && TSTZRANGE(?, ?)
            WHERE #{thing_alias.right}.id = a.thing_id
            GROUP BY a.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = #{thing_alias.right}.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string(geo_order_string, ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      def proximity_in_occurrence_pia(ordering = '', value = {}, sort_by_date = true)
        start_date, end_date = date_from_filter_object(value['in'] || value['v'], value['q']) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])

        if start_date.nil? && end_date.nil?
          start_date = Time.zone.now
          end_date = 1.week.from_now.end_of_week
        end
        if sort_by_date
          min_start_date = 'MIN(LOWER(so.occurrence))'
        else
          min_start_date = '1'
        end

        joined_table_name = "schedules_#{SecureRandom.hex(10)}"
        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN (
            SELECT
              a.thing_id,
              1 AS "occurrence_exists",
              #{min_start_date} as "min_start_date"
            FROM
              schedules a,
              UNNEST(a.occurrences) so(occurrence)
            WHERE so.occurrence && TSTZRANGE(?, ?)
            GROUP BY
              a.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = #{thing_alias.right}.id
        SQL

        join_tabel_name2 = "opening_hours_description_closed_#{SecureRandom.hex(10)}"
        order_parameter_join2 = <<-SQL.squish
          LEFT OUTER JOIN (
            SELECT 1 AS "closed_description_exists", cc.content_a_id
            FROM content_contents cc
            LEFT OUTER JOIN classification_contents clc ON clc.content_data_id = cc.content_b_id
            LEFT OUTER JOIN concepts c ON c.id = clc.classification_id  AND c.internal_name = 'geschlossen'
            LEFT OUTER JOIN concept_schemes cs ON cs.id = c.concept_scheme_id  AND cs.name = 'Öffnungszeiten'
            LEFT OUTER JOIN schedules s ON s.thing_id = cc.content_b_id AND s.relation = 'validity_schedule'
            WHERE cc.relation_a = 'opening_hours_description'
            AND s.occurrences && TSTZRANGE(#{"'#{start_date}'"}, #{"'#{start_date.end_of_day}'"})
          ) "#{join_tabel_name2}" ON #{join_tabel_name2}.content_a_id = #{thing_alias.right}.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join2]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string("#{join_tabel_name2}.closed_description_exists", ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
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
          min_start_date = 'MIN(LOWER(so.occurrence))'
        else
          min_start_date = '1'
        end

        joined_table_name = "schedules_#{SecureRandom.hex(10)}"
        order_parameter_join = <<-SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT a.thing_id,
              1 AS "occurrence_exists",
              CASE WHEN MIN(LOWER(so.occurrence)) IS NULL THEN NULL ELSE #{min_start_date} END as min_start_date
            FROM schedules a
            LEFT OUTER JOIN UNNEST(a.occurrences) so(occurrence) ON so.occurrence && TSTZRANGE(?, ?)
            WHERE #{thing_alias.right}.id = a.thing_id
            GROUP BY a.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = #{thing_alias.right}.id
        SQL

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [order_parameter_join, start_date, end_date]))
            .reorder(nil)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      def sort_fulltext_search(ordering, value)
        return self if value.blank?
        locale = @locale&.first || I18n.available_locales.first.to_s
        normalized_value = DataCycleCore::MasterData::DataConverter.string_to_string(value)
        return self if normalized_value.blank?
        search_string = normalized_value.split.join('%')

        order_string = ActiveRecord::Base.send(
          :sanitize_sql_for_conditions,
          [
            Arel.sql(
              "#{thing_alias.right}.boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery(pg_dict_mappings.dict, :search),16) +
              1 * similarity(searches.full_text, :search_string))"
            ),
            {search_string: "%#{search_string}%",
             search: normalized_value}
          ]
        )

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["LEFT JOIN searches ON searches.content_data_id = #{thing_alias.right}.id AND searches.locale = ? LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale", locale]))
            .reorder(nil)
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      def sort_ts_rank_fulltext_search(ordering, value)
        return self if value.blank?

        q = text_to_websearch_tsquery(value)
        locale = @locale&.first || I18n.available_locales.first.to_s

        reflect(
          @query
            .joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["LEFT JOIN searches ON searches.content_data_id = #{thing_alias.right}.id AND searches.locale = ? LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale", locale]))
            .reorder(nil)
            .order(
              sanitized_order_string(ActiveRecord::Base.send(:sanitize_sql_for_order, [Arel.sql('ts_rank_cd(searches.search_vector, websearch_to_prefix_tsquery(pg_dict_mappings.dict, ?), 5)'), q]), ordering, true),
              thing_alias[:updated_at].desc,
              thing_alias[:id].desc
            )
        )
      end

      alias sort_fulltext_search sort_ts_rank_fulltext_search if Feature::TsQueryFulltextSearch.enabled?
      alias sort_similarity sort_fulltext_search

      def sanitized_ordering(ordering)
        ordering = ordering&.downcase

        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for ordering: #{ordering}" unless ['asc', 'desc'].include?(ordering)

        ordering
      end

      def sanitized_order_string(order_string, order, nulls_last = false)
        ordering = sanitized_ordering(order)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for order string: #{order_string}" if order_string.blank?

        order_nulls = nulls_last ? ' NULLS LAST' : ''
        Arel.sql(ActiveRecord::Base.send(:sanitize_sql_for_order, "#{order_string} #{ordering}#{order_nulls}"))
      end
    end
  end
end
