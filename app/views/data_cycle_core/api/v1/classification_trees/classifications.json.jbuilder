json.partial! 'classifications', classification_aliases: @classification_aliases

json.partial! 'pagination_links',
  objects: @classification_aliases,
  object_url: ->(params) { api_v1_classification_tree_url(@classification_tree_label, params) }