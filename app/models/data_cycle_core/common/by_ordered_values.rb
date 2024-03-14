# frozen_string_literal: true

module DataCycleCore
  module Common
    module ByOrderedValues
      extend ActiveSupport::Concern

      included do
        scope :by_ordered_values, ->(ids, key = primary_key) { ids.present? ? where(key => ids).reorder(nil).order([Arel.sql("array_position(ARRAY[?]::uuid[], #{table_name}.#{key})"), ids]) : none }
      end
    end
  end
end
