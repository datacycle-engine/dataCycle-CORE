# frozen_string_literal: true

json.data do
  json.array!(@classification_tree_labels) do |classification_tree_label|
    json.id classification_tree_label.id
    json.name classification_tree_label.name
    json.url api_v2_classification_tree_url(classification_tree_label, language: @language, api_subversion: @api_subversion)
  end
end

json.partial! 'pagination_links',
              objects: @classification_tree_labels,
              object_url: ->(params) { api_v2_classification_trees_url(params) }
