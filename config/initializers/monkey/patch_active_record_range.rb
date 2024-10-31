# frozen_string_literal: true

# add dateformat with fractional seconds
Time::DATE_FORMATS[:long_usec] = '%Y-%m-%d %H:%M:%S.%N %z'
Time::DATE_FORMATS[:long_msec] = '%Y-%m-%dT%H:%M:%S.%3N%:z'
Time::DATE_FORMATS[:long_datetime] = '%Y-%m-%dT%H:%M:%S'
Time::DATE_FORMATS[:only_date] = '%Y-%m-%d'
Time::DATE_FORMATS[:only_time] = '%H:%M'
Time::DATE_FORMATS[:compact_datetime] = '%Y-%m-%dT%H-%M'

class Time
  LONG_AGO = Time.zone.local(1400, 1, 1, 0, 0)
end

# patch for ActiveRecord, to allow fractional seconds to be saved for PostgreSQL tstzrange datatype
# TODO: remove if updated upstream
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Range < Type::Value
          def cast_value(value)
            return if value == 'empty'
            return value unless value.is_a?(::String)

            extracted = extract_bounds(value)
            from = type_cast_single extracted[:from]
            to = type_cast_single extracted[:to]

            raise ArgumentError, "The Ruby Range object does not support excluding the beginning of a Range. (unsupported value: '#{value}')" if !infinity?(from) && extracted[:exclude_start]
            if to.instance_of?(::Time) && from.instance_of?(::Float)
              ::Range.new(Time::LONG_AGO, to, extracted[:exclude_end])
            else
              ::Range.new(from, to, extracted[:exclude_end])
            end
          end

          def serialize(value)
            if value.is_a?(::Range)
              from = type_cast_single_for_database(value.begin)
              from = nil if value.begin.is_a?(Time) && value.begin <= Time::LONG_AGO
              to = type_cast_single_for_database(value.end)
              [
                '[',
                from.is_a?(Time) ? from.to_fs(:long_usec) : from,
                ',',
                to.is_a?(Time) ? to.to_fs(:long_usec) : to,
                value.exclude_end? ? ')' : ']'
              ].join('')
            else
              super
            end
          end
        end
      end
    end
  end
end
