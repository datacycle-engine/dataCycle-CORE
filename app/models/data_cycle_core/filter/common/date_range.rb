# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module DateRange
        def in_schedule(value = nil, mode = nil)
          return if value.blank?
          from_date, to_date = date_from_filter_object(value, mode)
          schedule_search(from_date&.beginning_of_day, to_date&.end_of_day, 'schedule')
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
