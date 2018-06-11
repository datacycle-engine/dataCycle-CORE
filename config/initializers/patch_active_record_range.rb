# frozen_string_literal: true

# add dateformat with fractional seconds
Time::DATE_FORMATS[:long_usec] = '%Y-%m-%d %H:%M:%S.%N %z'

# patch for ActiveRecord, to allow fractional seconds to be saved for PostgreSQL tstzrange datatype
# TODO: remove if updated upstream
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Range < Type::Value
          def serialize(value)
            if value.is_a?(::Range)
              from = type_cast_single_for_database(value.begin)
              to = type_cast_single_for_database(value.end)
              [
                '[',
                from.is_a?(Time) ? from.to_s(:long_usec) : from,
                ',',
                to.is_a?(Time) ? to.to_s(:long_usec) : to,
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
