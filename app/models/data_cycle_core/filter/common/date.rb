# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Date
        def in_schedule(value = nil, mode = nil, attribute_key = nil)
          return if value.blank?

          attribute_key = 'event_schedule' if attribute_key == 'schedule' # keep backwards compatibity for APIv4 filter[attribute][schedule]
          from_date, to_date = date_from_filter_object(value, mode)
          schedule_search(from_date, to_date, attribute_key)
        end

        def schedule_search(from, to, relation = nil)
          return self if from.blank? && to.blank?

          from_node = from.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from.is_a?(::Date) ? from.beginning_of_day : from)
          to_node = to.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to.is_a?(::Date) ? to.end_of_day : to)

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel::SelectManager.new(schedule)
                  .project(1)
                  .where(
                    (relation.present? ? schedule[:relation].eq(Arel::Nodes.build_quoted(relation)) : schedule[:relation].not_in(DataCycleCore::Feature::AdvancedFilter.schedule_filter_exceptions))
                    .and(schedule[:thing_id].eq(thing[:id]))
                    .and(
                      Arel::Nodes::Exists.new(
                        Arel::SelectManager.new(schedule_occurrence)
                          .project(1)
                          .where(
                            schedule_occurrence[:schedule_id].eq(schedule[:id])
                            .and(overlap(tstzrange(from_node, to_node), schedule_occurrence[:occurrence]))
                          )
                      )
                    )
                  )
              )
            )
          )
        end

        def validity_period(value = nil, mode = nil)
          return if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)

          date_range = "[#{from_date},#{to_date}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ['things.validity_range @> ?::tstzrange', date_range])
          reflect(
            @query.where(query_string)
          )
        end

        def in_validity_period(current_date = nil)
          current_date ||= Time.zone.now
          reflect(
            @query.where(in_range(thing[:validity_range], cast_tstz(current_date)))
          )
        end

        def inactive_things(value = nil, mode = nil)
          return if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)

          date_range = "[#{from_date},#{to_date}]"
          # "interval 1 second" is required because upper(RANGE) 01-01-2000 23:59:59 in Ruby is 02-01-2000 00:00:00 in Postgresql
          query_string = Thing.send(:sanitize_sql_for_conditions, ['upper(things.validity_range) <> \'infinity\' AND (upper(things.validity_range) - interval \'1 second\') <@ ?::tstzrange', date_range])

          reflect(
            @query.where(query_string)
          )
        end

        def not_validity_period(value = nil, mode = nil)
          from_date, to_date = date_from_filter_object(value, mode)

          date_range = "[#{from_date},#{to_date}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ['things.validity_range @> ?::tstzrange', date_range])
          reflect(
            @query.where.not(query_string)
          )
        end

        def date_range(d = nil, attribute_path = nil)
          from_date, to_date = date_from_filter_object(d, nil)

          date_range = "[#{from_date},#{to_date}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

          reflect(
            @query.where(query_string)
          )
        end

        def not_date_range(d = nil, attribute_path = nil)
          from_date, to_date = date_from_filter_object(d, nil)

          date_range = "[#{from_date},#{to_date}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

          reflect(
            @query.where.not(query_string)
          )
        end

        def modified_at(d = nil)
          date_range(d, 'updated_at')
        end

        def created_at(d = nil)
          date_range(d, 'created_at')
        end

        def event_end_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          reflect(
            @query.where(cast_ts(in_json(thing[:metadata], 'start_date')).lteq(Arel::Nodes.build_quoted(time.iso8601)))
          )
        end

        def event_from_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          reflect(
            @query.where(cast_ts(in_json(thing[:metadata], 'end_date')).gteq(Arel::Nodes.build_quoted(time.iso8601)))
          )
        end

        def date_from_single_value(value)
          return if value.blank?
          return value if value.is_a?(::Date)

          DataCycleCore::MasterData::DataConverter.string_to_datetime(value)
        end

        def date_from_filter_object(value, mode)
          mode ||= 'absolute'
          value.stringify_keys!
          min = value.dig('from') || value.dig('min')
          max = value.dig('until') || value.dig('max')

          if mode == 'absolute'
            from_date = date_from_single_value(min)
            to_date = date_from_single_value(max)
            to_date = to_date.end_of_day if to_date&.to_s(:only_time) == '00:00'
          else
            from_date = relative_to_absolute_date(min)
            to_date = relative_to_absolute_date(max)
          end

          raise DataCycleCore::Error::Filter::DateFilterRangeError, [from_date, to_date] if !to_date.nil? && from_date&.>(to_date)

          return from_date, to_date
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

        module_function :date_from_filter_object
        module_function :date_from_single_value
        module_function :relative_to_absolute_date
      end
    end
  end
end
