# frozen_string_literal: true

class AddGlobalFlagToStoredFilter < ActiveRecord::Migration[5.2]
  def change
    add_column :stored_filters, :linked_stored_filter_id, :uuid
  end
end
