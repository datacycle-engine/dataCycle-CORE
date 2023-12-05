# frozen_string_literal: true

class ValidateExternalHashesForeignKeysAgain < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      ALTER TABLE external_hashes VALIDATE CONSTRAINT fk_external_hashes_things;
    SQL
  end

  def down
  end
end
