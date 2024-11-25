# frozen_string_literal: true

class RemoveInverseConnectionsForAggregates < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE content_contents
      SET relation_b = NULL
      WHERE content_contents.relation_b IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM things
          WHERE things.id = content_contents.content_a_id
            AND things.aggregate_type = 'aggregate'
        )
        AND content_contents.relation_a != 'aggregate_for';
    SQL
  end

  def down
  end
end
