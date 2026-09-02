# frozen_string_literal: true

class AddSuccessfulDatesToExternalSource < ActiveRecord::Migration[5.2]
  # rubocop:disable-next Rails/BulkChangeTable
  def change
    add_column :external_sources, :last_successful_download, :datetime
    add_column :external_sources, :last_successful_import, :datetime
  end
end
