# frozen_string_literal: true

class RemoveUnusedClassificationContents < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DELETE FROM classification_contents
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = classification_contents.content_data_id
        );
    SQL
  end

  def down
  end
end
