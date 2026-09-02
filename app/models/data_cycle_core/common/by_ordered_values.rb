# frozen_string_literal: true

module DataCycleCore
  module Common
    module ByOrderedValues
      extend ActiveSupport::Concern

      included do
        # orders the given values by their position in the array, e.g. by_ordered_values(['b', 'a']) => ['b', 'a']
        scope :by_ordered_values, lambda { |values, key = primary_key|
          next none if values.blank?

          column = columns_hash[key.to_s]

          raise ArgumentError, "unknown column (#{key}) for #{klass.name}" if column.nil?

          # untyped array literals are compared as text, values are serialized through the column
          # type first (normalizes e.g. uuids) so the positions still line up
          ordered_values = Array.wrap(values).map { |v| type_for_attribute(column.name).serialize(v) }
          quoted_column = "#{quoted_table_name}.#{ActiveRecord::Base.connection.quote_column_name(column.name)}"
          position = Arel.sql("array_position(ARRAY[?]::text[], #{quoted_column}::text)")

          where(key => values)
            .reorder(nil)
            .order(ActiveRecord::Base.send(:sanitize_sql_for_order, [position, ordered_values]))
        }
      end
    end
  end
end
