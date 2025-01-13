# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
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
            reflect(@query.where.not(subquery.project(1).exists))
          else
            reflect(@query.where(subquery.project(1).exists))
          end
        end

        private

        def graph_filter_query(filter, relation = nil, inverse = false)
          filter_query = related_to_filter_query(filter)
          thing_id = :content_a_id
          related_to_id = :content_b_id
          thing_id, related_to_id = related_to_id, thing_id if inverse

          sub_select = content_content_link[thing_id].eq(thing[:id])
          sub_select = sub_select.and(content_content_link[related_to_id].in(filter_query)) if filter_query.present?
          sub_select = sub_select.and(content_content_link[:relation].eq(relation)) if relation.present?

          Arel::SelectManager.new.from(content_content_link).where(sub_select)
        end

        def graph_joins_query(filter, relation = nil, inverse = false)
          filter_query = related_to_filter_query(filter)
          thing_id = :content_a_id
          related_to_id = :content_b_id
          thing_id, related_to_id = related_to_id, thing_id if inverse

          ccl_alias = "ccl#{SecureRandom.hex(5)}"
          joins_query = ["INNER JOIN content_content_links #{ccl_alias} ON #{ccl_alias}.#{thing_id} = #{thing_alias.right}.id AND #{ccl_alias}.#{related_to_id} IN (?)", filter_query]

          if relation.present?
            joins_query[0] += " AND #{ccl_alias}.relation IN (?)"
            joins_query << relation
          end

          @query.joins(sanitize_sql(joins_query))
        end

        def not_graph_joins_query_joins_query(filter, relation = nil, inverse = false)
          filter_query = related_to_filter_query(filter)
          thing_id = :content_a_id
          related_to_id = :content_b_id
          thing_id, related_to_id = related_to_id, thing_id if inverse

          ccl_alias = "ccl#{SecureRandom.hex(5)}"
          joins_query = ["LEFT OUTER JOIN content_content_links #{ccl_alias} ON #{ccl_alias}.#{thing_id} = #{thing_alias.right}.id AND #{ccl_alias}.#{related_to_id} IN (?)", filter_query]

          if relation.present?
            joins_query[0] += " AND #{ccl_alias}.relation IN (?)"
            joins_query << relation
          end

          @query.joins(sanitize_sql(joins_query)).where("#{ccl_alias}.id IS NULL")
        end
      end
    end
  end
end
