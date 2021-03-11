# frozen_string_literal: true

class MigrateMetadataToursToColumnLine < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      UPDATE things
      SET line = st_multi(st_geometryfromtext(metadata ->> 'tour', 4326))
      where metadata ->> 'tour' is not NULL;
    SQL
  end

  def down
  end
end
