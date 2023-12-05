# frozen_string_literal: true

class ValidateForeignKeysForClassificationContents < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    output = execute <<-SQL.squish
      DELETE FROM classification_contents
      WHERE NOT EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = classification_contents.content_data_id
        );
    SQL

    puts "classification_contents -> things (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :classification_contents, :things
  end

  def down
  end
end
