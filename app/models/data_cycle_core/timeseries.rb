# frozen_string_literal: true

module DataCycleCore
  class Timeseries < ApplicationRecord
    self.primary_key = :thing_id
    belongs_to :thing, class_name: 'DataCycleCore::Thing'

    after_create do |item|
      item.thing.invalidate_self
    end

    def self.create_all(content, data)
      inserted = 0
      updated = 0
      plain_rows = []

      transaction do
        # fixed order (not insertion order) so two concurrent calls touching the same
        # properties always take their per-property advisory locks the same way round,
        # ruling out a lock-ordering deadlock between them
        data.group_by { |item| item[:property] }.sort_by { |property, _| property }.each do |property, items|
          if content.properties_for(property)&.dig('collapse_redundant_values')
            points = items.map { |item| { timestamp: item[:timestamp], value: item[:value] } }
            result = RedundantValueCollapser.new(thing_id: content.id, property:).call(points)
            inserted += result[:inserted]
            updated += result[:updated]
          else
            plain_rows.concat(items)
          end
        end

        inserted += insert_all(plain_rows, unique_by: :thing_attribute_timestamp_idx, returning: :thing_id).count if plain_rows.present?
      end

      if inserted.positive? || updated.positive?
        dependent_keys = content.dependent_computed_property_names(data.pluck(:property).uniq)
        DataCycleCore::ComputePropertiesJob.perform_later(content.id, dependent_keys) if dependent_keys.present?
        content.invalidate_self
      end

      {
        meta: {
          thing_id: content.id,
          # duplicates also covers points collapsed into an existing run, not just exact index conflicts
          processed: {
            inserted:,
            duplicates: data.size - inserted
          }
        }
      }
    rescue ActiveRecord::NotNullViolation, ActiveRecord::RecordInvalid, RedundantValueCollapser::InvalidTimestampError
      { error: 'wrong format for timestamps' }
    end
  end
end
