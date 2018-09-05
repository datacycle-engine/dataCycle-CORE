# frozen_string_literal: true

class AddMoreIndices < ActiveRecord::Migration[5.1]
  def change
    add_index :watch_lists, :id unless index_exists?(:watch_lists, :id)
    add_index :watch_lists, :user_id unless index_exists?(:watch_lists, :user_id)
    add_index :user_groups, :id unless index_exists?(:user_groups, :id)
    add_index :releases, :id unless index_exists?(:releases, :id)
    add_index :classifications, [:deleted_at, :external_source_id, :external_key], name: 'extid_extkey_del_idx' unless index_exists?(:classifications, [:deleted_at, :external_source_id, :external_key], name: 'extid_extkey_del_idx')
    add_index :classification_groups, [:deleted_at, :classification_id], name: 'deleted_at_classification_id_idx' unless index_exists?(:classification_groups, [:deleted_at, :classification_id], name: 'deleted_at_classification_id_idx')
    add_index :classification_aliases, [:deleted_at, :id], name: 'deleted_at_id_idx' unless index_exists?(:classification_aliases, [:deleted_at, :id], name: 'deleted_at_id_idx')
    add_index :classification_trees, [:deleted_at, :classification_alias_id], name: 'deleted_at_classification_alias_id_idx' unless index_exists?(:classification_trees, [:deleted_at, :classification_alias_id], name: 'deleted_at_classification_alias_id_idx')
    add_index :creative_works, [:template, :template_name], name: 'cw_template_template_name_idx' unless index_exists?(:creative_works, [:template, :template_name], name: 'cw_template_template_name_idx')
    add_index :events, [:template, :template_name], name: 'ev_template_template_name_idx' unless index_exists?(:events, [:template, :template_name], name: 'ev_template_template_name_idx')
    add_index :organizations, [:template, :template_name], name: 'or_template_template_name_idx' unless index_exists?(:organizations, [:template, :template_name], name: 'or_template_template_name_idx')
    add_index :persons, [:template, :template_name], name: 'pe_template_template_name_idx' unless index_exists?(:persons, [:template, :template_name], name: 'pe_template_template_name_idx')
    add_index :places, [:template, :template_name], name: 'pl_template_template_name_idx' unless index_exists?(:places, [:template, :template_name], name: 'pl_template_template_name_idx')
  end
end
