# frozen_string_literal: true

module DataCycleCore
  module Common
    module ByOrderedValues
      extend ActiveSupport::Concern

      included do
        scope :by_ordered_values, ->(ids, key = primary_key) { ids.present? ? where(key => ids).reorder(nil).order(ActiveRecord::Base.send(:sanitize_sql_for_order, [Arel.sql("array_position(ARRAY[?]::#{columns_hash[key.to_s].sql_type}[], #{table_name}.#{key})"), ids])) : none }
      end
    end
  end
end
