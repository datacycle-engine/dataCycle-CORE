# frozen_string_literal: true

class RemoveOrderStringFromStoredFilterParameters < ActiveRecord::Migration[5.2]
  def up
    # return unless ActiveRecord::Base.connection.table_exists? 'stored_filters'

    # DataCycleCore::StoredFilter.find_each do |filter|
    #   order_hash = filter.parameters&.select { |f| f['t'] == 'order' }&.first || []
    #   next if order_hash.blank?
    #   parameters = filter.parameters.without(order_hash)
    #   filter.parameters = parameters
    #   filter.save(touch: false)
    # end
  end

  def down
  end
end
