# frozen_string_literal: true

class MigrateEventsDcPotentialActionToPotentialAction < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE
        content_contents
      SET
        relation_a = 'potential_action'
      WHERE
        relation_a = 'dc_potential_action';

      UPDATE
        content_content_histories
      SET
        relation_a = 'potential_action'
      WHERE
        relation_a = 'dc_potential_action';
    SQL

    DataCycleCore::RunTaskJob.perform_later('dc:migrate:potential_action_string_to_embedded')
  end

  def down
  end
end
