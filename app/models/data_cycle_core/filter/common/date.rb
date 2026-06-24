# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      # Methods for parsing and applying date-related filters.
      module Date
        # Filter things that have schedule occurrences overlapping the given date filter object.
        #
        # `attribute_key` supports the historical alias 'schedule' for backwards compatibility of APIv4 filter[attribute][schedule].
        def in_schedule(value = nil, _mode = nil, attribute_key = nil)
          return none if value.blank?

          attribute_key = 'event_schedule' if attribute_key == 'schedule'
          schedule_search(value, attribute_key)
        end

        # Builds an EXISTS subquery against the schedules table for the current thing.
        #
        # When `relation` is provided it restricts schedules to those relations (used for offers/offer_periods).
        # By default it excludes relations listed in `schedule_filter_exceptions` to avoid matching auxiliary schedules that should not be exposed via filters.
        def schedule_search(value, relation = [], include_all: false)
          from_node, to_node = arel_date_from_filter_object(value)

          return self if from_node.blank? && to_node.blank?

          subquery = DataCycleCore::Schedule.where(schedule[:thing_id].eq(thing[:id]))

          subquery = if relation.present?
                       subquery.where(relation: relation)
                     elsif include_all
                       subquery
                     else
                       subquery.where.not(relation: DataCycleCore::Feature::AdvancedFilter.schedule_filter_exceptions)
                     end

          subquery = subquery.where(overlap(tstzrange(from_node, to_node), schedule[:occurrences]))

          reflect(@query.where(subquery.select(1).arel.exists))
        end

        # `schedule_search` in offer-related schedules.
        def offer_period(value = nil, _mode = nil)
          return none if value.blank?

          schedule_search(value, ['offer_period_schedules', 'offers'])
        end

        # Filter things whose `:validity_range` intersects the provided date filter range.
        def validity_period(value = nil, _mode = nil)
          return none if value.blank?

          from_node, to_node = arel_date_from_filter_object(value)

          reflect(
            @query.where(
              in_range(thing[:validity_range], tstzrange(from_node, to_node))
            )
          )
        end

        # Negated `validity_period` — returns things whose `:validity_range` do NOT have any overlap with the given range.
        def not_validity_period(value = nil, _mode = nil)
          from_node, to_node = arel_date_from_filter_object(value)

          reflect(
            @query.where.not(
              in_range(thing[:validity_range], tstzrange(from_node, to_node))
            )
          )
        end

        # Filter things that are valid at `current_date`.
        #
        # Defaults to the beginning of the current day.
        def in_validity_period(current_date = nil)
          current_date ||= Time.zone.now.beginning_of_day
          reflect(
            @query.where(in_range(thing[:validity_range], cast_tstz(current_date)))
          )
        end

        # Find things that became inactive inside the given range.
        #
        # A thing is considered inactive when the upper bound of its `:validity_range` is not infinite and the instant before that upper bound falls into the requested range.
        # We subtract one second to interpret the transition moment as the end of availability.
        def inactive_things(value = nil, _mode = nil)
          return none if value.blank?

          from_node, to_node = arel_date_from_filter_object(value)

          reflect(
            @query.where(
              upper_range(thing[:validity_range]).not_eq(infinity)
              .and(
                contained_in_range(subtract(upper_range(thing[:validity_range]), interval('1 second')), tstzrange(from_node, to_node))
              )
            )
          )
        end

        # Filter by a tsrange filter object intersecting the given attribute (e.g. `created_at` / `updated_at`).
        def date_range(d = nil, attribute_path = nil)
          from_node, to_node = arel_date_from_filter_object(d, 'cast_ts')

          reflect(
            @query.where(
              in_range(tsrange(from_node, to_node), thing[attribute_path.to_sym])
            )
          )
        end

        # Negated `date_range` — returns rows where the attribute does not intersect the supplied tsrange.
        def not_date_range(d = nil, attribute_path = nil)
          from_node, to_node = arel_date_from_filter_object(d, 'cast_ts')

          reflect(
            @query.where.not(
              in_range(tsrange(from_node, to_node), thing[attribute_path.to_sym])
            )
          )
        end

        # Filter by a tsrange filter object intersecting the `updated_at` attribute.
        def modified_at(d = nil)
          date_range(d, 'updated_at')
        end

        # Filter by a tsrange filter object intersecting the `created_at` attribute.
        def created_at(d = nil)
          date_range(d, 'created_at')
        end

        # Filter events whose parsed `start_date` is less than or equal to the supplied time.
        #
        # `time` may be a string; it is normalised to a DateTime so comparisons
        # are deterministic and compatible with the stored JSON metadata.
        def event_end_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          reflect(
            @query.where(cast_ts(in_json(thing[:metadata], 'start_date')).lteq(Arel::Nodes.build_quoted(time.iso8601)))
          )
        end

        # Filter events whose parsed `end_date` is greater than or equal to the supplied time.
        def event_from_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          reflect(
            @query.where(cast_ts(in_json(thing[:metadata], 'end_date')).gteq(Arel::Nodes.build_quoted(time.iso8601)))
          )
        end

        # Parse a filter object containing `from`/`until` or `min`/`max`.
        #
        # Raises `DataCycleCore::Error::Filter::DateFilterRangeError` if bounds are inverted.
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
          end

          raise DataCycleCore::Error::Filter::DateFilterRangeError, [from_date, to_date] if !to_date.nil? && from_date&.>(to_date)

          return from_date, to_date
        end

        # Convert the parsed from/to values into ARel nodes using the provided range conversion function (default: `cast_tstz`).
        #
        # Dates are normalised to day boundaries (beginning_of_day/end_of_day) to provide intuitive semantics for date-only filters.
        def arel_date_from_filter_object(value, range_function = 'cast_tstz')
          assert_date_filter_bounds!(value)

          value ||= {}
          value.stringify_keys!
          min = value['from'] || value['min']
          max = value['until'] || value['max']

          if min.is_a?(Hash) || max.is_a?(Hash)
            from_node = send(range_function, relative_to_absolute_arel_date(min))
            to_node = send(range_function, relative_to_absolute_arel_date(max))
          else
            from_date = date_from_single_value(min)
            to_date = date_from_single_value(max)

            from_date = from_date.beginning_of_day if from_date.is_a?(::Date)
            to_date = to_date.end_of_day if to_date.is_a?(::Date)

            from_node = from_date.blank? ? nil : send(range_function, from_date)
            to_node = to_date.blank? ? nil : send(range_function, to_date)
          end

          return from_node, to_node
        end

        # Raises `DataCycleCore::Error::Filter::DateFilterRangeError` if bounds are inverted.
        def assert_date_filter_bounds!(value)
          _, __ = date_from_filter_object(value)
        end

        # Builds an ARel call to the database-side `relative_date(jsonb)` function for relative-to-absolute date conversion.
        #
        # Expects a hash containing keys `n` and `unit` and an optional `mode` (p for plus/forward).
        # Returns an ARel node representing the function call (e.g. `relative_date('{"n":2,"unit":"day","mode":"m"}'::jsonb)`) or nil for invalid payloads.
        def relative_to_absolute_arel_date(value)
          return if value.blank? || !value.is_a?(::Hash)

          value = value.stringify_keys
          distance = value['n']&.presence&.to_i

          return if distance.blank?

          payload = value.slice('n', 'unit', 'mode').compact
          json_literal = ActiveRecord::Base.connection.quote(payload.to_json)

          Arel::Nodes::NamedFunction.new(
            'relative_date',
            [Arel::Nodes::SqlLiteral.new("#{json_literal}::jsonb")]
          )
        end

        # Supported relative-date units mapped to ActiveSupport::Duration helpers.
        # Mirrors the unit handling of the database-side `relative_date(jsonb)` (unknown/blank unit -> days),
        # and avoids `Integer#send(arbitrary_method)` which could call any Integer method (e.g. 'abs').
        RELATIVE_DATE_UNITS = {
          'minute' => :minutes,
          'hour' => :hours,
          'day' => :days,
          'week' => :weeks,
          'month' => :months,
          'year' => :years
        }.freeze

        # Ruby-based implementation for relative-to-absolute date conversion.
        #
        # Expects a hash containing keys `n` and `unit` and an optional `mode` (p for plus/forward).
        # Returns a Time instance or nil for invalid payloads. Mirrors the database-side `relative_date`.
        def relative_to_absolute_date(value)
          return if value.blank?

          distance = value['n']&.presence&.to_i

          return if distance.blank?

          duration = distance.public_send(RELATIVE_DATE_UNITS.fetch(value['unit'], :days))

          value['mode'] == 'p' ? Time.zone.now + duration : Time.zone.now - duration
        end

        # Convert a single filter value into a Date/DateTime object.
        def date_from_single_value(value)
          return if value.blank?
          return value if value.is_a?(::Date)

          if value.is_a?(String) && !value.match?(/T\d{2}:\d{2}|\s+\d{1,2}:\d{2}/)
            DataCycleCore::MasterData::DataConverter.string_to_date(value)
          else
            DataCycleCore::MasterData::DataConverter.string_to_datetime(value)
          end
        end

        module_function :date_from_filter_object
        module_function :assert_date_filter_bounds!
        module_function :relative_to_absolute_arel_date
        module_function :relative_to_absolute_date
        module_function :date_from_single_value
      end
    end
  end
end
