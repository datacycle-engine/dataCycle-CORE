# frozen_string_literal: true

class MigrateAuthorStringToAuthorName < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE thing_translations
      SET content = thing_translations.content - 'author' || jsonb_build_object(
          'author_name',
          thing_translations.content->'author'
        )
      WHERE thing_translations.content->>'author' IS NOT NULL;
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE thing_translations
      SET content = thing_translations.content - 'author_name' || jsonb_build_object(
          'author',
          thing_translations.content->'author_name'
        )
      WHERE thing_translations.content->>'author_name' IS NOT NULL;
    SQL
  end
end
