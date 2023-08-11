# frozen_string_literal: true

class VacuumAfterCleanup < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      VACUUM things, thing_translations, thing_histories, thing_history_translations;
    SQL
  end

  def down
  end
end
