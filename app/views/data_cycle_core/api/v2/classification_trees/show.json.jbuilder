# frozen_string_literal: true

json.data do
  json.id @classification_tree_label.id
  json.name @classification_tree_label.name

  json.classifications classifications_api_v2_classification_tree_url(@api_subversion, @classification_tree_label, language: @language)
end
