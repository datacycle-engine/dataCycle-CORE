# frozen_string_literal: true

json.data do
  json.id @concept_scheme.id
  json.name @concept_scheme.name

  json.classifications classifications_api_v2_classification_tree_url(@api_subversion, @concept_scheme, language: @language)
end
