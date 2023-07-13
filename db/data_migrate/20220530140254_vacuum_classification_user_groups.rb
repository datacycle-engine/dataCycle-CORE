# frozen_string_literal: true

class VacuumClassificationUserGroups < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      VACUUM ANALYZE classification_user_groups;
    SQL
  end

  def down
  end
end
