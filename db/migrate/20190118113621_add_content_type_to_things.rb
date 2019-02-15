# frozen_string_literal: true

class AddContentTypeToThings < ActiveRecord::Migration[5.1]
  def up
    add_column :things, :content_type, :string
    add_column :thing_histories, :content_type, :string

    execute <<-SQL
      UPDATE things SET content_type = schema ->> 'content_type';
      UPDATE thing_histories SET content_type = schema ->> 'content_type';
    SQL

    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_boost;
      CREATE INDEX IF NOT EXISTS index_things_on_boost_updated_at ON things (boost, updated_at);
      CREATE INDEX IF NOT EXISTS index_things_on_template_content_type ON things (template, content_type);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_boost_updated_at;
      DROP INDEX IF EXISTS index_things_on_template_content_type;
      CREATE INDEX IF NOT EXISTS index_things_on_boost ON things (boost DESC NULLS LAST);
    SQL
    remove_column :things, :content_type
    remove_column :thing_histories, :content_type
  end
end
