# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sortable
      # The sorts that order by distance - in time, in space, or both - together with the geo and
      # schedule helpers only they use. They stay mixed into the same query object, so reflect,
      # query_without_order, sanitized_order_string and invalid_sort_argument! still resolve.
      module Proximity
        # The lower bound arrives either as the request's filter object ({'in' => {'min' => '2026-09-02T13:29:10.494Z'}})
        # or as a stored in_schedule filter ({'q' => 'relative', 'v' => {'from' => {'n' => '0', 'mode' => 'p', 'unit' => 'day'}}}),
        # whose relative bounds SortParamTransformations#merge_api_schedule_params resolves to absolute Times while 'q' keeps
        # reading 'relative' - so 'q' cannot tell the shapes apart, and date_from_filter_object parses all of them.
        def sort_proximity_in_time(_ordering = '', value = {})
          date = date_from_filter_object(value['in'] || value['v']).first if value.is_a?(::Hash)
          date ||= Time.zone.now

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

        # sort_proximity_geographic falls back to filter[geo][in][perimeter] and leaves the query
        # unsorted when that is absent. This key instead carries its own coordinates in
        # sort: proximity.geographic_with(14,46), so an argument that yields no pair -
        # sort: proximity.geographic_with(x), or the bare key - is a client error, not a silent no-op.
        def sort_proximity_geographic_with(ordering = '', value = [])
          invalid_sort_argument!('proximity.geographic_with requires a longitude and a latitude', value) unless valid_geographic_coordinates?(value)

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
          #     LEFT OUTER JOIN concept_contents clc ON clc.content_data_id = cc.content_b_id
          #     LEFT OUTER JOIN concepts c ON c.id = clc.concept_id  AND c.internal_name = 'geschlossen'
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

        private

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

        # True only when both coordinates parse as numbers, so non-numeric values never reach the
        # interpolated literal above (DC-19). Invalid input leaves the query unsorted, except for
        # sort_proximity_geographic_with, which has no filter to fall back on and rejects it.
        #
        # The Array check rejects a sort argument that was never parsed into a pair: String#[]
        # indexes characters, so "14" would otherwise pass as lon "1" / lat "4" and sort by
        # POINT (1.0 4.0).
        def valid_geographic_coordinates?(value)
          value.is_a?(::Array) && !Float(value[0], exception: false).nil? && !Float(value[1], exception: false).nil?
        end
      end
    end
  end
end
