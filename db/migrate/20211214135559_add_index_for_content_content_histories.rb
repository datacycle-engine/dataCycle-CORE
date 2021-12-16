# frozen_string_literal: true

class AddIndexForContentContentHistories < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS index_content_content_histories_on_content_a_history_id ON content_content_histories (content_a_history_id);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS index_content_content_histories_on_content_a_history_id;
    SQL
  end
end
