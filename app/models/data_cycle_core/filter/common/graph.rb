# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      # Provides filtering methods for graph relationships between content items.
      #
      # This module enables querying content based on their relationships through
      # the ContentContent::Link association. It supports various filter operations
      # including existence checks, negations, and like queries for related content.
      #
      # @example Check if content has related items
      #   filter.exists_graph_filter(nil, 'images', query)
      #
      # @example Filter by specific relationship
      #   filter.graph_filter(filter_params, 'parent_items', query)
      module Graph
        extend ActiveSupport::Concern

        def graph_filter(filter, name, query)
          common_graph_filter_prep(filter, name, query, false)
        end

        def not_graph_filter(filter, name, query)
          common_graph_filter_prep(filter, name, query, true)
        end

        def exists_graph_filter(_filter, name, query)
          common_graph_filter_prep(nil, name, query, false)
        end

        def not_exists_graph_filter(_filter, name, query)
          common_graph_filter_prep(nil, name, query, true)
        end

        def like_graph_filter(filter, name, query)
          common_graph_filter_prep(filter, name, query, false)
        end

        def not_like_graph_filter(filter, name, query)
          common_graph_filter_prep(filter, name, query, true)
        end

        def common_graph_filter_prep(filter, name, query, exclude = false)
          subquery = graph_filter_query(filter, name, query == 'items_linked_to')
          return self if subquery.nil?

          if exclude
            reflect(@query.where.not(subquery))
          else
            reflect(@query.where(subquery))
          end
        end

        private

        def graph_filter_query(filter, relation = nil, inverse = false)
          filter_query = related_to_filter_query(filter)
          thing_id = :content_a_id
          related_to_id = :content_b_id
          thing_id, related_to_id = related_to_id, thing_id if inverse
          relation = Array.wrap(relation).compact_blank

          query = DataCycleCore::ContentContent::Link.select(1)
            .where(content_content_link[thing_id].eq(thing[:id]))
          query = query.where(relation: relation) if relation.present?
          query = query.where(related_to_id => filter_query) unless filter_query.nil?

          query.arel.exists
        end
      end
    end
  end
end
