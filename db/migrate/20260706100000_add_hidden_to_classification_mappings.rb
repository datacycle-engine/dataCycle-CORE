# frozen_string_literal: true

# Redmine #47172: allow classification mappings ("related" concept_links /
# classification_groups) to be marked as "hidden".
#
# * classification_groups.hidden       -> admin-writable source of truth
# * concept_links.hidden               -> synced from classification_groups, read by the CCC generators
# * concept_link_histories.hidden      -> keeps the (dynamic) history copy consistent
# * classification_alias_paths_transitive.hidden_ids -> set of concept ids in a path that are
#                                         reached through a hidden mapping (alignment-free carrier)
# * collected_classification_contents.hidden -> per-thing materialized flag used by all read sites
class AddHiddenToClassificationMappings < ActiveRecord::Migration[8.0]
  def up
    add_column :classification_groups, :hidden, :boolean, default: false, null: false, if_not_exists: true
    add_column :concept_links, :hidden, :boolean, default: false, null: false, if_not_exists: true
    add_column :concept_link_histories, :hidden, :boolean, default: false, null: false, if_not_exists: true
    add_column :collected_classification_contents, :hidden, :boolean, default: false, null: false, if_not_exists: true
    add_column :classification_alias_paths_transitive, :hidden_ids, :uuid, array: true, default: [], null: false, if_not_exists: true
  end

  def down
    remove_column :classification_alias_paths_transitive, :hidden_ids, if_exists: true
    remove_column :collected_classification_contents, :hidden, if_exists: true
    remove_column :concept_link_histories, :hidden, if_exists: true
    remove_column :concept_links, :hidden, if_exists: true
    remove_column :classification_groups, :hidden, if_exists: true
  end
end
