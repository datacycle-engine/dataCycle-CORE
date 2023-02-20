# frozen_string_literal: true

class SetInitialManuelOrderForWatchListDataHashes < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE watch_list_data_hashes
      SET
        order_a = w.order_a
      FROM
        (
          SELECT
            wldh.id,
            (
              ROW_NUMBER() OVER (
                PARTITION BY
                  wldh.watch_list_id
                ORDER BY
                  wldh.created_at
              )
            ) AS order_a
          FROM
            watch_list_data_hashes wldh
        ) w
      WHERE
        w.id = watch_list_data_hashes.id;
    SQL
  end

  def down
  end
end
