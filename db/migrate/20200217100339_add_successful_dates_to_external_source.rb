# frozen_string_literal: true

class AddSuccessfulDatesToExternalSource < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def change
    add_column :external_sources, :last_successful_download, :datetime
    add_column :external_sources, :last_successful_import, :datetime
  end
  # rubocop:enable Rails/BulkChangeTable
end
