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
                                                                           depth: depth.to_i
                                                                         ])}) content_contents").reorder(order_a: :asc)
        end

        def recursive_content_content_a(depth: 0)
          DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                           self.class.send(:recursive_content_content_a_query, depth:),
                                                                           id:,
                                                                           depth: depth.to_i
                                                                         ])}) content_contents").reorder(order_a: :asc)
        end

        class_methods do
          def recursive_content_links(depth: 0, preload: false)
            load_relation(
              relation_name: :content_content_a,
              scope: DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      recursive_content_links_query(depth:),
                                                                                      id: current_scope.pluck(:id),
                                                                                      depth: depth.to_i
                                                                                    ])}) content_contents").reorder(order_a: :asc),
              preload:
            )
          end

          def recursive_content_content_a(depth: 0, preload: false)
            load_relation(
              relation_name: :content_content_a,
              scope: DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      recursive_content_content_a_query(depth:),
                                                                                      id: current_scope.pluck(:id),
                                                                                      depth: depth.to_i
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
                #{depth&.positive? ? ", content_tree.depth + 1 >= :depth AS \"leaf\", CASE WHEN content_content_links.relation = 'overlay' THEN content_tree.depth ELSE content_tree.depth + 1 END AS \"depth\"" : ', FALSE AS "leaf"'}
              FROM content_content_links
                INNER JOIN content_tree ON content_tree.content_b_id = content_content_links.content_a_id
              WHERE content_content_links.relation IS NOT NULL
            SQL

            if depth&.positive?
              recursive_subquery << ' ' + <<-SQL.squish
                AND NOT content_tree.leaf
              SQL
            end

            <<-SQL.squish
              WITH RECURSIVE content_tree(id, content_b_id, relation, leaf #{', depth' if depth&.positive?}) AS (
                SELECT content_content_links.content_content_id,
                  content_content_links.content_b_id,
                  content_content_links.relation,
                  #{depth == 1 ? "content_content_links.relation != 'overlay'" : 'FALSE'} AS "leaf"
                  #{", CASE WHEN content_content_links.relation = 'overlay' THEN 0 ELSE 1 END AS \"depth\"" if depth&.positive?}
                FROM content_content_links
                WHERE content_content_links.content_a_id IN (:id)
                AND content_content_links.relation IS NOT NULL
                UNION #{'ALL' if depth&.positive?}
                #{recursive_subquery}
              )
              SELECT DISTINCT ON (content_contents.id) content_contents.*, content_tree.leaf FROM content_contents
              INNER JOIN content_tree ON content_tree.id = content_contents.id
              ORDER BY content_contents.id ASC #{', content_tree.depth ASC' if depth&.positive?}
            SQL
          end

          def recursive_content_content_a_query(depth: 0)
            recursive_subquery = <<-SQL.squish
              SELECT content_contents.id,
              content_contents.content_b_id,
              content_contents.relation_a
                #{depth&.positive? ? ", content_tree.depth + 1 >= :depth AS \"leaf\", CASE WHEN content_contents.relation_a = 'overlay' THEN content_tree.depth ELSE content_tree.depth + 1 END AS \"depth\"" : ', FALSE AS "leaf"'}
              FROM content_contents
                INNER JOIN content_tree ON content_tree.content_b_id = content_contents.content_a_id
            SQL

            if depth&.positive?
              recursive_subquery << ' ' + <<-SQL.squish
                WHERE NOT content_tree.leaf
              SQL
            end

            <<-SQL.squish
              WITH RECURSIVE content_tree(id, content_b_id, relation_a, leaf #{', depth' if depth&.positive?}) AS (
                SELECT content_contents.id,
                  content_contents.content_b_id,
                  content_contents.relation_a,
                  #{depth == 1 ? "content_contents.relation_a != 'overlay'" : 'FALSE'} AS "leaf"
                  #{", CASE WHEN content_contents.relation_a = 'overlay' THEN 0 ELSE 1 END AS \"depth\"" if depth&.positive?}
                FROM content_contents
                WHERE content_contents.content_a_id IN (:id)
                UNION #{'ALL' if depth&.positive?}
                #{recursive_subquery}
              )
              SELECT DISTINCT ON (content_contents.id) content_contents.*, content_tree.leaf FROM content_contents
              INNER JOIN content_tree ON content_tree.id = content_contents.id
              ORDER BY content_contents.id ASC #{', content_tree.depth ASC' if depth&.positive?}
            SQL
          end
        end
      end
    end
  end
end
