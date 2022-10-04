# frozen_string_literal: true

class AddDefaultValuesForTimeStamps < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE classification_contents ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE classification_contents ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
      ALTER TABLE classification_content_histories ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE classification_content_histories ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
      ALTER TABLE content_contents ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE content_contents ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
      ALTER TABLE content_content_histories ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE content_content_histories ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE classification_contents ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE classification_contents ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE classification_content_histories ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE classification_content_histories ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE content_contents ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE content_contents ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE content_content_histories ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE content_content_histories ALTER COLUMN updated_at DROP DEFAULT;
    SQL
  end
end
