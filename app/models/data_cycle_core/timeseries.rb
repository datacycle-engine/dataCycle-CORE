# frozen_string_literal: true

module DataCycleCore
  class Timeseries < ApplicationRecord
    self.primary_key = :thing_id
    belongs_to :thing, class_name: 'DataCycleCore::Thing'

    after_create do |item|
      item.thing.invalidate_self
    end

    def self.create_all(content, data)
      result = insert_all(data, unique_by: :thing_attribute_timestamp_idx, returning: :thing_id)
      inserted = result.count
      content.invalidate_self if inserted.positive?

      {
        meta: {
          thing_id: content.id,
          processed: {
            inserted:,
            duplicates: data.size - inserted
          }
        }
      }
    rescue ActiveRecord::NotNullViolation, ActiveRecord::RecordInvalid
      { error: 'wrong format for timestamps' }
    end
  end
end
