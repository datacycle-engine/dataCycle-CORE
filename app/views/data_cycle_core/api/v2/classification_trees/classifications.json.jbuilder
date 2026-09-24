# frozen_string_literal: true

json.partial! 'classifications', concepts: @concepts, key: 'data'

json.partial! 'pagination_links',
              objects: @concepts,
              object_url: ->(params) { classifications_api_v2_classification_tree_url(@api_subversion, @concept_scheme, params) }
