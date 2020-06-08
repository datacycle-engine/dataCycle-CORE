# frozen_string_literal: true

json.classificationTree do
  json.id @classification_tree_label.id
  json.name @classification_tree_label.name

  json.classifications classifications_api_v1_classification_tree_url(@classification_tree_label)
end
