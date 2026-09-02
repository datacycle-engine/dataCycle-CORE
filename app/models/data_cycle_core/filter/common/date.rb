# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      # Methods for parsing and applying date-related filters.
      module Date
        SKIP_VALIDITY_FILTERS_KEY = :data_cycle_core_skip_validity_filters
        # `date_range` attribute paths come from the `advanced_filter.date_range` config (and from
        # stored filters created with it), where a value may be a JSON path into a jsonb column
        # (e.g. `metadata ->> 'upload_date'`) instead of a plain `things` column.
        DATE_RANGE_JSON_PATH = /\A\s*(?<column>\w+)\s*->>?\s*'(?<key>[^']+)'\s*\z/

        class << self
          # Runs the block with the validity filters (#validity_period, #in_validity_period and their
          # negations) turned into no-ops.
          #
          # Deliberately not solved by removing the validity parameters from a StoredFilter: a filter
          # reaches them through parameter types that resolve a StoredFilter of their own
          # (+filter_ids+, +union_filter_ids+, +union+ - see StoredFilterExtensions::FilterParamsHashParser
          # and Filter::Common::Union), whose parameters no caller can strip. Switching the filter
          # methods off instead survives every nesting level.
          #
          # A relation built inside the block keeps the bypass when it is executed later: the filter
          # methods run while the query is assembled, and nested StoredFilters are resolved to SQL
          # right there. Only relations *built* outside the block are unaffected.
          #
          # Note that this cannot reach a StoredFilter that answers from its cache
          # (StoredFilterExtensions::Cachable) - the cached set was materialized with the validity
          # filter applied. Callers that need the bypass therefore have to run uncached, which a
          # +StoredFilter.new+ (no +cached_result+) does at every level.
          #
          # The state lives in +Thread.current+ (as in Turbo::ThreadThrottler), not in a Rails store.
          # Note that +Thread#[]+ is fiber-local, not thread-local: a query built inside a +Fiber+, an
          # +Enumerator+ or a +.lazy+ chain opened in the block does not see the bypass and applies the
          # validity filter again. That is the safe direction to fail in, and neither Filter:: nor
          # StoredFilter uses any of them today - but it is the assumption this switch rests on.
          # @return [Object] the return value of the block
          def without_validity_filters
            previous = Thread.current[SKIP_VALIDITY_FILTERS_KEY]
            Thread.current[SKIP_VALIDITY_FILTERS_KEY] = true

            yield
          ensure
            Thread.current[SKIP_VALIDITY_FILTERS_KEY] = previous
          end

          # @return [Boolean] whether the validity filters are currently switched off
          def validity_filters_disabled?
            Thread.current[SKIP_VALIDITY_FILTERS_KEY].present?
          end
        end

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
          return self if DataCycleCore::Filter::Common::Date.validity_filters_disabled?
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
          return self if DataCycleCore::Filter::Common::Date.validity_filters_disabled?

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
          return self if DataCycleCore::Filter::Common::Date.validity_filters_disabled?

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
              in_range(tsrange(from_node, to_node), date_range_attribute(attribute_path))
            )
          )
        end

        # Negated `date_range` — returns rows where the attribute does not intersect the supplied tsrange.
        def not_date_range(d = nil, attribute_path = nil)
          from_node, to_node = arel_date_from_filter_object(d, 'cast_ts')

          reflect(
            @query.where.not(
              in_range(tsrange(from_node, to_node), date_range_attribute(attribute_path))
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
        # Relative dates are resolved in Ruby (see `relative_to_absolute_date`) and embedded as absolute
        # literals; the database-side `relative_date(jsonb)` function is intentionally NOT used here — it
        # is opaque to the query planner and regressed production performance (#50369). The function is
        # kept in the schema for hand-written Grafana queries.
        #
        # Dates are normalised to day boundaries (beginning_of_day/end_of_day) to provide intuitive semantics for date-only filters.
        def arel_date_from_filter_object(value, range_function = 'cast_tstz')
          from, to = date_from_filter_object(value)

          from_node = if from.blank?
                        nil
                      else
                        send(range_function, from.is_a?(::Date) ? from.beginning_of_day : from)
                      end
          to_node = if to.blank?
                      nil
                    else
                      send(range_function, to.is_a?(::Date) ? to.end_of_day : to)
                    end

          return from_node, to_node
        end

        # Relative-to-absolute date conversion used by the filter query builder.
        #
        # Expects a hash containing keys `n` and `unit` and an optional `mode` (p for plus/forward).
        # Returns a Time instance or nil for invalid payloads.
        #
        # Ruby is the source of truth for relative dates; the database-side `relative_date(jsonb)`
        # function (kept only for Grafana) mirrors it for all real inputs. Malformed units are the one
        # exception where we do NOT match it: the SQL `ELSE` falls back to days, whereas here an
        # unrecognised unit yields nil. The `case` (not `distance.send(value['unit'])`) keeps user
        # input from invoking arbitrary Integer methods (e.g. 'abs').
        def relative_to_absolute_date(value)
          return if value.blank?

          distance = value['n']&.presence&.to_i

          return if distance.blank?

          unit = value['unit'] || 'day'
          duration = case unit
                     when 'minute' then distance.minutes
                     when 'hour' then distance.hours
                     when 'day' then distance.days
                     when 'week' then distance.weeks
                     when 'month' then distance.months
                     when 'year' then distance.years
                     end

          return if duration.nil?

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

        private

        # The JSON form yields text, so it needs a cast to be comparable to the tsrange.
        def date_range_attribute(attribute_path)
          match = DATE_RANGE_JSON_PATH.match(attribute_path.to_s)

          return thing[attribute_path.to_sym] if match.nil?

          cast_ts(in_json(thing[match[:column].to_sym], match[:key]))
        end

        module_function :date_from_filter_object
        module_function :relative_to_absolute_date
        module_function :date_from_single_value
      end
    end
  end
end
