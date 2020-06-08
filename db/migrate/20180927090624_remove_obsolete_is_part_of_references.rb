# frozen_string_literal: true

class RemoveObsoleteIsPartOfReferences < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      UPDATE creative_works
      SET is_part_of = NULL
      WHERE schema ->> 'content_type' = 'embedded' AND is_part_of IS NOT NULL;

      UPDATE creative_work_histories
      SET is_part_of = NULL
      WHERE schema ->> 'content_type' = 'embedded' AND is_part_of IS NOT NULL;
    SQL
  end
end
