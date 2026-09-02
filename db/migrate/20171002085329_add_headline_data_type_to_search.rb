# frozen_string_literal: true

class AddHeadlineDataTypeToSearch < ActiveRecord::Migration[5.0]
  # rubocop:disable-next Rails/BulkChangeTable
  def change
    add_column :searches, :headline, :string
    add_column :searches, :data_type, :string
  end
end
