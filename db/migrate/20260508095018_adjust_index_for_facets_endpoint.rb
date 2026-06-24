# frozen_string_literal: true

class AdjustIndexForFacetsEndpoint < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :collected_classification_contents, [:classification_tree_label_id, :thing_id, :link_type], name: 'ccc_ctl_id_t_id_cai_idx', include: :classification_alias_id, if_not_exists: true, algorithm: :concurrently
    remove_index :collected_classification_contents, name: 'ccc_ctl_id_t_id_idx', if_exists: true
  end

  def down
    add_index :collected_classification_contents, [:classification_tree_label_id, :thing_id, :link_type], name: 'ccc_ctl_id_t_id_idx', if_not_exists: true, algorithm: :concurrently
    remove_index :collected_classification_contents, name: 'ccc_ctl_id_t_id_cai_idx', if_exists: true
  end
end
