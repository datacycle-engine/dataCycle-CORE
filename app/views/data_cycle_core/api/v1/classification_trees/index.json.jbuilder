# frozen_string_literal: true

json.classificationTrees do
  json.array!(@classification_tree_labels) do |classification_tree_label|
    json.id classification_tree_label.id
    json.name classification_tree_label.name
    json.url api_v1_classification_tree_url(classification_tree_label)
  end
end

json.partial! 'pagination_links',
              objects: @classification_tree_labels,
              object_url: ->(params) { api_v1_classification_trees_url(params) }
