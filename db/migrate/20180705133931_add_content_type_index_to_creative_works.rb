# frozen_string_literal: true

class AddContentTypeIndexToCreativeWorks < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      CREATE INDEX index_creative_works_on_content_type ON creative_works ((schema ->> 'content_type'))
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX index_creative_works_on_content_type
    SQL
  end
end
