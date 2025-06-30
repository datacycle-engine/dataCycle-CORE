# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Date
        def in_schedule(value = nil, mode = nil, attribute_key = nil)
          return none if value.blank?

          attribute_key = 'event_schedule' if attribute_key == 'schedule' # keep backwards compatibity for APIv4 filter[attribute][schedule]
          from_date, to_date = date_from_filter_object(value, mode)
          schedule_search(from_date, to_date, attribute_key)
        end

        def schedule_search(from, to, relation = [])
          return self if from.blank? && to.blank?

          from_node = from.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from.is_a?(::Date) ? from.beginning_of_day : from)
          to_node = to.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to.is_a?(::Date) ? to.end_of_day : to)

          subquery = DataCycleCore::Schedule.where(schedule[:thing_id].eq(thing[:id]))

          if relation.present?
            subquery = subquery.where(relation: relation)
          else
            subquery = subquery.where.not(relation: DataCycleCore::Feature::AdvancedFilter.schedule_filter_exceptions)
          end

          subquery = subquery.where(overlap(tstzrange(from_node, to_node), schedule[:occurrences]))

          reflect(@query.where(subquery.select(1).arel.exists))
        end

        def validity_period(value = nil, mode = nil)
          return none if value.blank?

          from_date, to_date = date_from_filter_object(value, mode)
          from_node = from_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from_date.is_a?(::Date) ? from_date.beginning_of_day : from_date)
          to_node = to_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to_date.is_a?(::Date) ? to_date.end_of_day : to_date)

          reflect(
            @query.where(
              in_range(thing[:validity_range], tstzrange(from_node, to_node))
            )
          )
        end

        def in_validity_period(current_date = nil)
          current_date ||= Time.zone.now.beginning_of_day
          reflect(
            @query.where(in_range(thing[:validity_range], cast_tstz(current_date)))
          )
        end

        def inactive_things(value = nil, mode = nil)
          return none if value.blank?

          from_date, to_date = date_from_filter_object(value, mode)
          from_node = from_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from_date.is_a?(::Date) ? from_date.beginning_of_day : from_date)
          to_node = to_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to_date.is_a?(::Date) ? to_date.end_of_day : to_date)

          reflect(
            @query.where(
              upper_range(thing[:validity_range]).not_eq(infinity)
              .and(
                contained_in_range(subtract(upper_range(thing[:validity_range]), interval('1 second')), tstzrange(from_node, to_node))
              )
            )
          )
        end

        def not_validity_period(value = nil, mode = nil)
          from_date, to_date = date_from_filter_object(value, mode)
          from_node = from_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(from_date.is_a?(::Date) ? from_date.beginning_of_day : from_date)
          to_node = to_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_tstz(to_date.is_a?(::Date) ? to_date.end_of_day : to_date)

          reflect(
            @query.where.not(
              in_range(thing[:validity_range], tstzrange(from_node, to_node))
            )
          )
        end

        def offer_period(value = nil, mode = nil)
          return none if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)

          schedule_search(from_date, to_date, ['offer_period_schedules', 'offers'])
        end

        def date_range(d = nil, attribute_path = nil)
          from_date, to_date = date_from_filter_object(d, nil)
          from_node = from_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_ts(from_date.is_a?(::Date) ? from_date.beginning_of_day : from_date)
          to_node = to_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_ts(to_date.is_a?(::Date) ? to_date.end_of_day : to_date)

          reflect(
            @query.where(
              in_range(tsrange(from_node, to_node), thing[attribute_path.to_sym])
            )
          )
        end

        def not_date_range(d = nil, attribute_path = nil)
          from_date, to_date = date_from_filter_object(d, nil)
          from_node = from_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_ts(from_date.is_a?(::Date) ? from_date.beginning_of_day : from_date)
          to_node = to_date.blank? ? Arel::Nodes::SqlLiteral.new('NULL') : cast_ts(to_date.is_a?(::Date) ? to_date.end_of_day : to_date)

          reflect(
            @query.where.not(
              in_range(tsrange(from_node, to_node), thing[attribute_path.to_sym])
            )
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

        def date_from_filter_object(value, _mode = nil)
          value ||= {}
          value.stringify_keys!
          min = value['from'] || value['min']
          max = value['until'] || value['max']

          if min.is_a?(Hash) || max.is_a?(Hash)
            from_date = relative_to_absolute_date(min)
            to_date = relative_to_absolute_date(max)
          else
            from_date = date_from_single_value(min)
            to_date = date_from_single_value(max)
            to_date = to_date.end_of_day if to_date&.to_fs(:only_time) == '00:00'
          end

          raise DataCycleCore::Error::Filter::DateFilterRangeError, [from_date, to_date] if !to_date.nil? && from_date&.>(to_date)

          return from_date, to_date
        end

        def relative_to_absolute_date(value)
          distance = value['n']&.presence&.to_i

          return if distance.blank?

          unit = value['unit'] || 'day'

          if value['mode'] == 'p'
            date = Time.zone.now + distance.send(unit)
          else
            date = Time.zone.now - distance.send(unit)
          end

          date
        end

        def from_as_time(from)
          from_time = from.presence
          from_time.is_a?(::Date) ? from_time.beginning_of_day : from_time
        end

        def to_as_time(to)
          to_time = to.presence
          to_time.is_a?(::Date) ? to_time.end_of_day : to_time
        end

        module_function :date_from_filter_object
        module_function :date_from_single_value
        module_function :relative_to_absolute_date
      end
    end
  end
end
