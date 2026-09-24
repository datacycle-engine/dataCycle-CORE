# frozen_string_literal: true

json.partial! 'classifications', concepts: @concepts

json.partial! 'pagination_links',
              objects: @concepts,
              object_url: ->(params) { classifications_api_v1_classification_tree_url(@concept_scheme, params) }
