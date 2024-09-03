# frozen_string_literal: true

module ActiveRecordUnion
  extend ActiveSupport::Concern

  class_methods do
    def union_subquery(*relations)
      return '1 = 0' if relations.empty?

      send(:sanitize_sql_array, ["\"#{table_name}\".\"#{primary_key}\" IN (#{relations.map(&:to_sql).compact_blank.join(' UNION ')})"])
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include ActiveRecordUnion
end
