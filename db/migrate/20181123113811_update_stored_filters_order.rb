# frozen_string_literal: true

class UpdateStoredFiltersOrder < ActiveRecord::Migration[5.1]
  def up
    DataCycleCore::StoredFilter.find_each do |filter|
      order_hash = filter.parameters&.select { |f| f['t'] == 'order' && f['v'].is_a?(Hash) }&.first || []
      next unless order_hash&.present?

      parameters = filter.parameters.without(order_hash).push(
        order_hash.map { |fk, fv| [fk, fv.is_a?(Hash) ? fv.map { |k, v| "searches.#{k} #{v.upcase}" }&.join(', ') : fv] }.to_h
      )
      filter.parameters = parameters
      filter.save(touch: false)
    end
  end

  def down
  end
end
