# frozen_string_literal: true

json.partial! 'classifications', classification_aliases: @classification_aliases, key: 'data'

json.partial! 'pagination_links',
              objects: @classification_aliases,
              object_url: ->(params) { classifications_api_v2_classification_tree_url(@api_subversion, @classification_tree_label, params) }
