# frozen_string_literal: true

class AddUniqueIndexToThingsForTemplates < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE things ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE things ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();


      CREATE UNIQUE INDEX IF NOT EXISTS things_template_name_template_uq_idx ON things (template_name, template)
      WHERE
        things.template = TRUE;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS things_template_name_template_uq_idx;

      ALTER TABLE things ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE things ALTER COLUMN updated_at DROP DEFAULT;
    SQL
  end
end
