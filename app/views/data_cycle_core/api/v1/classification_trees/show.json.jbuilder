# frozen_string_literal: true

json.classificationTree do
  json.id @concept_scheme.id
  json.name @concept_scheme.name

  json.classifications classifications_api_v1_classification_tree_url(@concept_scheme)
end
