# frozen_string_literal: true

require 'active_support/duration'

# activerecord/lib/active_record/connection_adapters/postgresql/oid/interval.rb
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Interval < Type::Value
          def type
            :interval
          end

          def cast_value(value)
            # puts "(cast_value) #{value.class} -> #{value}"
            case value
            when ::ActiveSupport::Duration
              value
            when ::String
              begin
                # do not allow mixing of W and any of Y,M,D -> delete W
                ::ActiveSupport::Duration.parse(value)
              rescue ::ActiveSupport::Duration::ISO8601Parser::ParsingError
                nil
              end
            else
              super
            end
          end

          def serialize(value)
            # puts "(serialize_value) #{value.class} -> #{value} // #{value.iso8601(precision: precision)}"
            case value
            when ::ActiveSupport::Duration
              value.iso8601(precision: precision)
            when ::Numeric
              # Sometimes operations on Times returns just float number of seconds so we need to handle that.
              # Example: Time.current - (Time.current + 1.hour) # => -3600.000001776 (Float)
              value.seconds.iso8601(precision: precision)
            else
              super
            end
          end
        end
      end
    end
  end
end

# activerecord/lib/active_record/connection_adapters/postgresql/schema_definitions.rb
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module SchemaDefinitions
        def interval(name, options = {})
          column(name, :interval, options)
        end
      end
    end
  end
end

# activerecord/lib/active_record/connection_adapters/postgresql/schema_statements.rb
require 'active_record/connection_adapters/postgresql/schema_statements'
module SchemaStatementsWithInterval
  def type_to_sql(type, limit: nil, precision: nil, scale: nil, array: nil, **)
    case type.to_s
    when 'interval'
      case precision
      when nil then 'interval'
      when 0..6 then "interval(#{precision})"
      else raise(ActiveRecordError, "No interval type has precision of #{precision}. The allowed range of precision is from 0 to 6")
      end
    else
      super
    end
  end
end
ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements.send(:prepend, SchemaStatementsWithInterval)

# activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
require 'active_record/connection_adapters/postgresql_adapter'
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:interval] = { name: 'interval' }
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  alias_method :initialize_type_map_without_interval, :initialize_type_map
  define_method :initialize_type_map do |m|
    initialize_type_map_without_interval(m)
    m.register_type 'interval' do |_, _, sql_type|
      precision = extract_precision(sql_type)
      ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID::Interval.new(precision: precision)
    end
  end

  alias_method :configure_connection_without_interval, :configure_connection
  define_method :configure_connection do
    configure_connection_without_interval
    execute('SET intervalstyle = iso_8601', 'SCHEMA')
  end

  ActiveRecord::Type.register(:interval, ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID::Interval, adapter: :postgresql)
end

module ActiveSupport
  class Duration
    class << self
      def build(value)
        raise TypeError, "can't build an #{name} from a #{value.class.name}" unless value.is_a?(::Numeric)

        parts = {}
        remainder = value.to_f

        (PARTS - [:weeks]).each do |part|
          next if part == :seconds
          part_in_seconds = PARTS_IN_SECONDS[part]
          parts[part] = remainder.div(part_in_seconds)
          remainder = (remainder % part_in_seconds).round(9)
        end

        parts[:seconds] = remainder

        new(value, parts)
      end
    end
  end
end
