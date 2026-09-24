# frozen_string_literal: true

json.data do
  json.array!(@concept_schemes) do |concept_scheme|
    json.id concept_scheme.id
    json.name concept_scheme.name
    json.url api_v2_classification_tree_url(concept_scheme, language: @language, api_subversion: @api_subversion)
  end
end

json.partial! 'pagination_links',
              objects: @concept_schemes,
              object_url: ->(params) { api_v2_classification_trees_url(params) }
