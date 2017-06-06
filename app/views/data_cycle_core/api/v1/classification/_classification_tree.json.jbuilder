types = DataCycleCore::ClassificationTree.
  joins(:classification_tree_label, :sub_classification_alias).
  joins(DataCycleCore::ClassificationTree.arel_table.join(DataCycleCore::ClassificationAlias.arel_table).
    on(DataCycleCore::ClassificationTree.arel_table[:classification_alias_id].eq(DataCycleCore::ClassificationAlias.arel_table[:id])).
    join_sources
  ).
  includes([:sub_classification_alias, :classification_tree_label]). # eager loading to avoid (n+1) loading in iteration
  where("classification_tree_labels.name = ?", tree_label.name).
  where("classification_tree_labels.external_source_id is NULL OR classification_tree_labels.external_source_id = '#{@external_source_id}'")

json.classification_aliases types do |item|
  json.set! "name", item.sub_classification_alias.name
  json.set! "parent_classification_alias_id", item.parent_classification_alias_id
  json.set! "classification_alias_id", item.classification_alias_id
  json.set! "tree_label", item.classification_tree_label.name
end
