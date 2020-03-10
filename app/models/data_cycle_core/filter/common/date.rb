# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Date
        def in_schedule(value = nil, mode = nil)
          return if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)
          schedule_search(from_date&.beginning_of_day, to_date&.end_of_day, 'schedule')
        end

        def schedule_search(from, to, relation = nil)
          return self if from.blank? && to.blank?
          @joined_schedule = true

          from_node = from.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from)
          to_node = to.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to)
          rdates = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new('unnest(schedules.rdate) AS event_date'))
          # occurrences = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new('unnest(get_occurrences(schedules.rrule::rrule, schedules.dtstart)) AS event_date'))
          occurrences = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new("unnest(get_occurrences(schedules.rrule::rrule, #{from.blank? ? 'schedules.dtstart' : from_node.to_sql}, #{to.blank? ? 'schedules.dtend' : to_node.to_sql})) AS event_date"))
          exdates = Arel::SelectManager.new.project('event_date').from(Arel::Nodes::SqlLiteral.new('unnest(schedules.exdate) AS event_date'))

          # binding.pry
          reflect(
            @query
              .left_outer_joins(:scheduled_data)
              .where(in_json(thing[:schema], 'schema_type').eq(Arel::Nodes.build_quoted('Event')))
              .where(
                overlap(tstzrange(from_node, to_node), tstzrange(thing[:start_date], thing[:end_date]))
                .and(
                  overlap(tstzrange(from_node, to_node), tstzrange(schedule[:dtstart], schedule[:dtend]))
                  .and(in_range(tstzrange(from_node, to_node), any(Arel::Nodes::Except.new(Arel::Nodes::UnionAll.new(rdates, occurrences), exdates))))
                  .and(relation.present? ? schedule[:relation].eq(Arel::Nodes.build_quoted(relation)) : Arel::Nodes::True.new)
                )
              )
          )
        end

        def validity_period(value = nil, mode = nil)
          return if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)

          date_range = "[#{from_date&.beginning_of_day},#{to_date&.end_of_day}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ['things.validity_range @> ?::tstzrange', date_range])
          reflect(
            @query.where(query_string)
          )
        end

        def in_validity_period(current_date = Time.zone.now)
          reflect(
            @query.where(in_range(thing[:validity_range], cast_tstz(current_date)))
          )
        end

        def inactive_things(value = nil, mode = nil)
          return if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)

          date_range = "[#{from_date&.beginning_of_day},#{to_date&.end_of_day}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ['upper(things.validity_range) <> \'infinity\' AND upper(things.validity_range) <@ ?::tstzrange', date_range])

          reflect(
            @query.where(query_string)
          )
        end

        def not_validity_period(value = nil, mode = nil)
          from_date, to_date = date_from_filter_object(value, mode)

          date_range = "[#{from_date&.beginning_of_day},#{to_date&.end_of_day}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ['things.validity_range @> ?::tstzrange', date_range])
          reflect(
            @query.where.not(query_string)
          )
        end

        def date_range(d = nil, attribute_path = nil)
          return self unless d.is_a?(Hash) && d.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present?

          date_range = "[#{d&.dig('from')&.to_s},#{d&.dig('until')&.to_s}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

          reflect(
            @query.where(query_string)
          )
        end

        def not_date_range(d = nil, attribute_path = nil)
          return self unless d.is_a?(Hash) && d.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present?

          date_range = "[#{d&.dig('from')&.to_s},#{d&.dig('until')&.to_s}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

          reflect(
            @query.where.not(query_string)
          )
        end

        def event_end_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          reflect(
            @query.where(thing[:start_date].lteq(Arel::Nodes.build_quoted(time.iso8601)))
          )
        end

        def event_from_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          reflect(
            @query.where(thing[:end_date].gteq(Arel::Nodes.build_quoted(time.iso8601)))
          )
        end

        def sort_by_proximity(date = Time.zone.now)
          reflect(
            @query.reorder(
              absolute_date_diff(thing[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
              absolute_date_diff(thing[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
              thing[:start_date]
            )
          )
        end

        private

        def date_from_filter_object(value, mode)
          mode ||= 'absolute'
          value.stringify_keys!

          if mode == 'absolute'
            from_date = date_from_single_value(value.dig('from'))
            to_date = date_from_single_value(value.dig('until'))
          else
            from_date = relative_to_absolute_date(value.dig('from'))
            to_date = relative_to_absolute_date(value.dig('until'))
          end

          return from_date, to_date
        end

        def date_from_single_value(value)
          return if value.blank?
          return value if value.is_a?(::Date)
          DataCycleCore::MasterData::DataConverter.string_to_datetime(value)
        end

        def relative_to_absolute_date(value)
          distance = value.dig('n')&.presence&.to_i
          return if distance.blank?

          unit = value.dig('unit') || 'day'
          if value.dig('mode') == 'p'
            date = Time.zone.now + distance.send(unit)
          else
            date = Time.zone.now - distance.send(unit)
          end
          date
        end
      end
    end
  end
end
