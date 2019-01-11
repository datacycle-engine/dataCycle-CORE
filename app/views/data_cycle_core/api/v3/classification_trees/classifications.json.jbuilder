# frozen_string_literal: true

json.partial! 'classifications', classification_aliases: @classification_aliases, key: 'data'

json.partial! 'pagination_links',
              objects: @classification_aliases,
              object_url: ->(params) { classifications_api_v3_classification_tree_url(@classification_tree_label, params) }
