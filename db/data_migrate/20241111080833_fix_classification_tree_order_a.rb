# frozen_string_literal: true

class FixClassificationTreeOrderA < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      SELECT public.update_classification_aliases_order_a(
          ARRAY_AGG(DISTINCT ct.classification_tree_label_id)
        )
      FROM classification_aliases ca
        JOIN classification_trees ct ON ct.classification_alias_id = ca.id
      WHERE ca.deleted_at IS NULL
        AND ct.deleted_at IS NULL
        AND ca.order_a IS NULL;
    SQL
  end

  def down
  end
end
