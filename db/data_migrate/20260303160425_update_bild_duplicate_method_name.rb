# frozen_string_literal: true

class UpdateBildDuplicateMethodName < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      UPDATE thing_duplicates
      SET method = 'bild_phash'
      WHERE method = 'phash';
    SQL
  end

  def down
  end
end
