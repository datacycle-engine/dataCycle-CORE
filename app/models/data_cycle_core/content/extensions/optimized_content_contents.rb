# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module OptimizedContentContents
        extend ActiveSupport::Concern

        def recursive_content_links(depth: 0)
          DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                           self.class.send(:recursive_content_links_query, depth:),
                                                                           id:,
                                                                           depth1: depth.to_i,
                                                                           depth2: depth.to_i + 1
                                                                         ])}) content_contents").reorder(order_a: :asc)
        end

        class_methods do
          def recursive_content_links(depth: 0, preload: false)
            load_relation(
              relation_name: :content_content_a,
              scope: DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      recursive_content_links_query(depth:),
                                                                                      id: current_scope.pluck(:id),
                                                                                      depth1: depth.to_i,
                                                                                      depth2: depth.to_i + 1
                                                                                    ])}) content_contents").reorder(order_a: :asc),
              preload:
            )
          end

          private

          def recursive_content_links_query(depth: 0)
            recursive_subquery = <<-SQL.squish
              SELECT content_content_links.content_content_id,
                content_content_links.content_b_id,
                content_content_links.relation
                #{depth&.positive? ? ', content_tree.depth >= :depth1 AS "leaf", content_tree.depth + 1 AS "depth"' : ', FALSE AS "leaf"'}
              FROM content_content_links
                INNER JOIN content_tree ON content_tree.content_b_id = content_content_links.content_a_id
            SQL

            if depth&.positive?
              recursive_subquery << ' ' + <<-SQL.squish
                WHERE (
                  content_tree.depth < :depth1
                  AND content_tree.relation != 'overlay'
                )
                OR (
                  content_tree.depth < :depth2
                  AND content_tree.relation = 'overlay'
                )
              SQL
            end

            <<-SQL.squish
              WITH RECURSIVE content_tree(id, content_b_id, relation, leaf #{', depth' if depth&.positive?}) AS (
                SELECT content_content_links.content_content_id,
                  content_content_links.content_b_id,
                  content_content_links.relation,
                  FALSE AS "leaf"
                  #{', 1 AS "depth"' if depth&.positive?}
                FROM content_content_links
                WHERE content_content_links.content_a_id IN (:id)
                UNION
                #{recursive_subquery}
              )
              SELECT content_contents.*, content_tree.leaf FROM content_contents
              INNER JOIN content_tree ON content_tree.id = content_contents.id
            SQL
          end
        end
      end
    end
  end
end
