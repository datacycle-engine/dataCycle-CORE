# frozen_string_literal: true

class VacuumAfterTemplateMigration < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      VACUUM things, thing_histories;
    SQL
  end

  def down
  end
end
