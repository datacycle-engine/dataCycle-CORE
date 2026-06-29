# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sortable
      def reset_sort
        reflect(query_without_order)
      end

      def sort_default(_ordering = 'DESC')
        reflect(
          query_without_order.order(
            thing[:boost].desc,
            thing[:updated_at].desc,
            thing[:id].desc
          )
        )
      end

      def sort_collection_manual_order(ordering, watch_list_id)
        return self if watch_list_id.nil?

        reflect(
          query_without_order
            .joins(
              sanitize_sql([
                             'LEFT OUTER JOIN watch_list_data_hashes ON watch_list_data_hashes.watch_list_id = ? AND watch_list_data_hashes.thing_id = things.id',
                             watch_list_id
                           ])
            )
            .order(
              watch_list_data_hash[:order_a].send(sanitized_ordering(ordering.presence || 'asc')),
              watch_list_data_hash[:created_at].asc,
              thing[:id].desc
            )
        )
      end

      # setseed does not work, if postgres spawns parallel workers for subqueries, so we use md5 hashing for random sorting with seed to ensure consistent results.
      def sort_random(_ordering = nil, seed = nil)
        order_string = if seed.present?
                         sanitize_sql_for_order([Arel.sql('md5(things.id || ?::TEXT)'), seed.to_s])
                       else
                         sanitize_sql_for_order('random()')
                       end

        reflect(query_without_order.order(order_string))
      end

      def sort_boost(ordering)
        reflect(
          query_without_order
            .order(
              thing[:boost].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end

      def sort_updated_at(ordering)
        reflect(
          query_without_order
            .order(
              thing[:updated_at].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end
      alias sort_dct_modified sort_updated_at

      def sort_cache_valid_since(ordering)
        reflect(
          query_without_order
            .order(
              thing[:cache_valid_since].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end
      alias sort_dc_touched sort_cache_valid_since

      def sort_created_at(ordering)
        reflect(
          query_without_order
            .order(
              thing[:created_at].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end
      alias sort_dct_created sort_created_at

      def sort_translated_name(ordering)
        locale = @locale&.first || I18n.default_locale.to_s

        reflect(
          query_without_order
            .joins(sanitize_sql(['LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = things.id AND thing_translations.locale = ?', locale]))
            .order(
              sanitized_order_string("thing_translations.content ->> 'name'", ordering, true),
              thing[:id].desc
            )
        )
      end
      alias sort_name sort_translated_name

      def sort_advanced_attribute(ordering, attribute_path)
        locale = @locale&.first || I18n.default_locale.to_s

        reflect(
          query_without_order
            .joins(sanitize_sql(['LEFT OUTER JOIN searches ON searches.content_data_id = things.id AND searches.locale = ?', locale]))
            .order(
              sanitized_order_string("searches.advanced_attributes -> '#{attribute_path}'", ordering, true),
              thing[:id].desc
            )
        )
      end

      def sort_proximity_in_time(_ordering = '', value = {})
        date = Time.zone.now
        if value.present? && value.is_a?(::Hash) && value['q'] == 'relative'
          date = relative_to_absolute_arel_date(value.dig('in', 'min')) if value.dig('in', 'min').present?
          date = relative_to_absolute_arel_date(value.dig('v', 'from')) if value.dig('v', 'from', 'n').present?
        elsif value.present? && value.is_a?(::Hash)
          date = date_from_single_value(value.dig('in', 'min')) if value.dig('in', 'min').present?
          date = date_from_single_value(value.dig('v', 'from')) if value.dig('v', 'from').present?
        end

        date = Arel::Nodes.build_quoted(date.iso8601) unless date.is_a?(Arel::Nodes::Node)
        reflect(
          query_without_order
            .order(
              absolute_date_diff(cast_ts(in_json(thing[:metadata], 'end_date')), date),
              absolute_date_diff(cast_ts(in_json(thing[:metadata], 'start_date')), date),
              cast_ts(in_json(thing[:metadata], 'start_date')),
              thing[:id].desc
            )
        )
      end

      # TODO: get the sort value for relation dynamically via data definitions
      def sort_by_proximity(ordering = '', value = {})
        from_node, to_node = arel_date_from_filter_object(value['in'] || value['v']) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])
        return self if from_node.nil? && to_node.nil?

        relation_filter = schedule_relation_filter(value, "AND schedules.relation != 'validity_range'")
        joined_table_name = "so#{SecureRandom.hex(10)}"
        order_parameter_join = <<~SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT schedules.thing_id,
              MIN(LOWER(so.occurrence)) AS "min_start_date"
            FROM schedules,
              UNNEST(schedules.occurrences_array) so(occurrence)
            WHERE things.id = schedules.thing_id
              AND so.occurrence && #{tstzrange(from_node, to_node, '[]').to_sql}
              #{relation_filter}
            GROUP BY schedules.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        reflect(
          query_without_order
            .joins(sanitize_sql([order_parameter_join]))
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      alias sort_by_schedule_proximity sort_by_proximity
      alias sort_proximity_occurrence sort_by_proximity

      def sort_proximity_geographic(ordering = '', value = [])
        return self unless valid_geographic_coordinates?(value)

        join_query, order_query = order_params_for_geom(value)
        reflect(
          query_without_order
            .joins(join_query)
            .order(
              sanitized_order_string(order_query, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
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

      def sort_proximity_in_occurrence_with_distance_pia(ordering = '', value = [])
        proximity_occurrence_with_distance_pia(ordering, value, false)
      end

      def proximity_occurrence_with_distance_pia(ordering = '', value = [], sort_by_date = true)
        return self if !value.is_a?(::Array) || value.first.blank?

        geo = value.first
        schedule = value.second
        return self unless valid_geographic_coordinates?(geo)

        if schedule.present? && schedule.is_a?(::Hash) && (schedule['in'] || schedule['v'])
          start_date, end_date = date_from_filter_object(schedule['in'] || schedule['v'], schedule['q'])
        else
          start_date = Time.zone.now
          end_date = 1.week.from_now.end_of_week
        end

        min_start_date = if sort_by_date
                           'MIN(LOWER(so.occurrence))'
                         else
                           '1'
                         end

        joined_table_name = "sch#{SecureRandom.hex(10)}"
        end_of_day = Time.zone.now.end_of_day
        end_date_extended = [end_date, 1.month.from_now.end_of_month].max

        # [TODO] @Samuel: check if it works as intended
        relation_filter = schedule_relation_filter(schedule, "AND schedules.relation = 'opening_hours_specification'")

        order_parameter_join = <<~SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT schedules.thing_id,
              CASE
                WHEN MIN(LOWER(so.occurrence)) IS NULL THEN NULL
                WHEN MIN(LOWER(so.occurrence)) FILTER (WHERE so.occurrence && TSTZRANGE(NOW(), '#{end_of_day}')) IS NOT NULL THEN 1
                WHEN MIN(LOWER(so.occurrence)) FILTER (WHERE so.occurrence && TSTZRANGE(:start_date, :end_date)) IS NOT NULL THEN 2
                ELSE 3
              END as occurrence_exists,
              CASE WHEN MIN(LOWER(so.occurrence)) IS NULL THEN NULL ELSE #{min_start_date} END as min_start_date
            FROM schedules
            LEFT OUTER JOIN UNNEST(schedules.occurrences_array) so(occurrence) ON so.occurrence && TSTZRANGE(NOW() - INTERVAL '1 year', '#{end_date_extended}')
            WHERE things.id = schedules.thing_id
            #{relation_filter}
            GROUP BY schedules.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        # join_tabel_name2 = "ohdc#{SecureRandom.hex(10)}"
        # order_parameter_join2 = <<-SQL.squish
        #   LEFT OUTER JOIN (
        #     SELECT 1 AS "closed_description_exists", cc.content_a_id
        #     FROM content_contents cc
        #     LEFT OUTER JOIN classification_contents clc ON clc.content_data_id = cc.content_b_id
        #     LEFT OUTER JOIN concepts c ON c.id = clc.classification_id  AND c.internal_name = 'geschlossen'
        #     LEFT OUTER JOIN concept_schemes cs ON cs.id = c.concept_scheme_id  AND cs.name = 'Öffnungszeiten'
        #     LEFT OUTER JOIN schedules s ON s.thing_id = cc.content_b_id AND s.relation = 'validity_schedule'
        #     WHERE cc.relation_a = 'opening_hours_description'
        #     AND s.occurrences && TSTZRANGE(#{"'#{start_date}'"}, #{"'#{start_date.end_of_day}'"})
        #   ) "#{join_tabel_name2}" ON #{join_tabel_name2}.content_a_id = things.id
        # SQL

        join_geo_query, order_geo_query = order_params_for_geom(geo)

        reflect(
          query_without_order
            .joins(sanitize_sql([order_parameter_join, { start_date: start_date, end_date: end_date }]))
            .joins(join_geo_query)
            # .joins(sanitize_sql([order_parameter_join2]))
            .order(
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              # sanitized_order_string("#{join_tabel_name2}.closed_description_exists", ordering, true),
              sanitized_order_string(order_geo_query, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      def proximity_occurrence_with_distance(ordering = '', value = [], sort_by_date = true)
        return self if !value.is_a?(::Array) || value.first.blank?

        geo = value.first
        schedule = value.second
        return self unless valid_geographic_coordinates?(geo)

        if schedule.present? && schedule.is_a?(::Hash) && (schedule['in'] || schedule['v'])
          start_date, end_date = date_from_filter_object(schedule['in'] || schedule['v'], schedule['q'])
        else
          start_date = Time.zone.now
          end_date = Time.zone.now.end_of_day
        end

        min_start_date = if sort_by_date
                           'MIN(LOWER(so.occurrence))'
                         else
                           '1'
                         end

        # [TODO] @Samuel: check if it works as intended
        relation_filter = schedule_relation_filter(schedule, "AND schedules.relation != 'validity_range'")

        joined_table_name = "sch#{SecureRandom.hex(10)}"
        order_parameter_join = <<~SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT schedules.thing_id,
              1 AS "occurrence_exists",
              CASE WHEN MIN(LOWER(so.occurrence)) IS NULL THEN NULL ELSE #{min_start_date} END as min_start_date
            FROM schedules
            LEFT OUTER JOIN UNNEST(schedules.occurrences_array) so(occurrence) ON so.occurrence && TSTZRANGE(:start_date, :end_date)
            WHERE things.id = schedules.thing_id
            #{relation_filter}
            GROUP BY schedules.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        join_geo_query, order_geo_query = order_params_for_geom(geo)

        reflect(
          query_without_order
            .joins(sanitize_sql([order_parameter_join, { start_date: start_date, end_date: end_date }]))
            .joins(join_geo_query)
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              sanitized_order_string(order_geo_query, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      def proximity_in_occurrence(ordering = '', value = {}, sort_by_date = true)
        start_date, end_date = date_from_filter_object(value['in'] || value['v'], value['q']) if value.present? && value.is_a?(::Hash) && (value['in'] || value['v'])

        if start_date.nil? && end_date.nil?
          start_date = Time.zone.now
          end_date = Time.zone.now.end_of_day
        end
        min_start_date = if sort_by_date
                           'MIN(LOWER(so.occurrence))'
                         else
                           '1'
                         end

        # [TODO] @Samuel: check if it works as intended
        relation_filter = schedule_relation_filter(value, "AND schedules.relation != 'validity_range'")

        joined_table_name = "sch#{SecureRandom.hex(10)}"
        order_parameter_join = <<~SQL.squish
          LEFT OUTER JOIN LATERAL (
            SELECT schedules.thing_id,
              1 AS "occurrence_exists",
              #{min_start_date} AS "min_start_date"
            FROM schedules
            INNER JOIN UNNEST(schedules.occurrences_array) so(occurrence) ON so.occurrence && TSTZRANGE(:start_date, :end_date)
            WHERE things.id = schedules.thing_id
            #{relation_filter}
            GROUP BY schedules.thing_id
          ) "#{joined_table_name}" ON #{joined_table_name}.thing_id = things.id
        SQL

        reflect(
          query_without_order
            .joins(sanitize_sql([order_parameter_join, { start_date: start_date, end_date: end_date }]))
            .order(
              sanitized_order_string("#{joined_table_name}.min_start_date", ordering, true),
              sanitized_order_string("#{joined_table_name}.occurrence_exists", ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      def sort_legacy_fulltext_search(ordering, value)
        return self if value.blank?

        locale = @locale&.first || I18n.default_locale.to_s
        normalized_value = DataCycleCore::MasterData::DataConverter.string_to_string(value)
        return self if normalized_value.blank?

        search_string = normalized_value.split.join('%')
        order_sql = <<~SQL.squish
          things.boost * (
            8 * similarity(searches.classification_string, :search_string) +
            4 * similarity(searches.headline, :search_string) +
            2 * ts_rank_cd(searches.words, plainto_tsquery(pg_dict_mappings.dict, :search),16) +
            1 * similarity(searches.full_text, :search_string)
          )
        SQL

        order_string = sanitize_sql([order_sql, { search_string: "%#{search_string}%", search: normalized_value }])

        reflect(
          query_without_order
            .joins(sanitize_sql(['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ? LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale', locale]))
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      def sort_ts_rank_fulltext_search(ordering, value)
        value, fields = value.values_at(:value, :fields) if value.is_a?(Hash)
        return self if value.blank?

        q = text_to_websearch_tsquery(value)
        weights = fulltext_fields_to_weights(fields)
        locale = @locale&.first || I18n.default_locale.to_s
        order_string = Feature::TsQueryFulltextSearch.sorting_string

        reflect(
          query_without_order
            .joins(sanitize_sql(['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ? LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale', locale]))
            .order(
              sanitized_order_string(sanitize_sql([order_string, { q:, weights: }]), ordering, true),
              thing[:id].desc
            )
        )
      end

      def sort_type(ordering, value)
        return self if value.blank?

        order_string = sanitize_sql(["array_position(ARRAY[?]::varchar[], CONCAT('dcls:', things.template_name))", value])
        # second variant to match parent types via array intersection, but performance is worse than the first one, so currently not used
        # order_string = sanitize_sql(['array_position(ARRAY[:value]::varchar[], (array_intersect(ARRAY [:value]::varchar [], thing_templates.api_schema_types))[1])', value])

        reflect(
          query_without_order
            # .joins(:thing_template)
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      def sanitized_ordering(ordering)
        ordering = ordering&.downcase

        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for ordering: #{ordering}" unless ['asc', 'desc'].include?(ordering)

        ordering
      end

      def sanitized_order_string(order_string, order, nulls_last = false)
        ordering = sanitized_ordering(order)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for order string: #{order_string}" if order_string.blank?

        order_nulls = nulls_last ? ' NULLS LAST' : ''
        Arel.sql(sanitize_sql_for_order("#{order_string} #{ordering}#{order_nulls}"))
      end

      # used to alias the fulltext search method based on feature flag without class reloading
      def self.alias_fulltext_search_method!
        if Feature::TsQueryFulltextSearch.enabled?
          alias_method :sort_fulltext_search, :sort_ts_rank_fulltext_search
        else
          alias_method :sort_fulltext_search, :sort_legacy_fulltext_search
        end
      end

      alias_fulltext_search_method!
      alias sort_similarity sort_fulltext_search

      private

      def query_without_order
        @query.reorder(nil).except(:joins)
      end

      def find_relation(value)
        return if value.blank?

        if value['relation']
          value['relation'].to_s.underscore
        elsif value.dig('v', 'relation')
          value.dig('v', 'relation').to_s.underscore
        end
      end

      def schedule_relation_filter(value, default_filter)
        relation_value = find_relation(value)
        return '' if relation_value == 'all'

        relation = relation_value.present? && !relation_value.eql?('schedule') ? relation_value : nil
        relation.present? ? "AND schedules.relation = #{ActiveRecord::Base.connection.quote(relation)}" : default_filter
      end

      def order_params_for_geom(value)
        order_parameter_join = <<~SQL.squish
          LEFT OUTER JOIN geometries ON geometries.thing_id = things.id AND geometries.is_primary = true
        SQL

        # SECURITY (DC-19): the coordinates are interpolated into a raw WKT literal inside the
        # ORDER BY clause, which sanitized_order_string wraps in Arel.sql (trusted). Coerce both
        # to Float so attacker-supplied sort values can never break out of the literal. Callers
        # guard with valid_geographic_coordinates? so this only raises if validation is bypassed.
        longitude = Float(value[0])
        latitude = Float(value[1])

        order_string = "geometries.geom_simple::geography <-> 'SRID=4326;POINT (#{longitude} #{latitude})'::geography"

        return order_parameter_join, order_string
      end

      # True only when both coordinates parse as numbers. Callers return self (unsorted) on
      # invalid input so non-numeric values never reach the interpolated literal above (DC-19).
      def valid_geographic_coordinates?(value)
        !Float(value&.[](0), exception: false).nil? && !Float(value&.[](1), exception: false).nil?
      end
    end
  end
end
