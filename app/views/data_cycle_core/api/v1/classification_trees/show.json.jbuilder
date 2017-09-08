json.classificaiton_tree do
  json.id @classification_tree_label.id
  json.name @classification_tree_label.name

  json.partial! 'classifications', classification_aliases: @classification_aliases
end

json.partial! 'pagination_links',
  objects: @classification_aliases,
  object_url: ->(params) { api_v1_classification_tree_url(@classification_tree_label, params) }
