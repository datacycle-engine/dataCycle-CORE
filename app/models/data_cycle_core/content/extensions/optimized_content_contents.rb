# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module OptimizedContentContents
        extend ActiveSupport::Concern

        def recursive_content_links(depth: 0)
          DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                           self.class.send(:recursive_content_links_query, depth:),
                                                                           {id:,
                                                                            depth: depth.to_i}
                                                                         ])}) content_contents").reorder(order_a: :asc)
        end

        def recursive_content_content_a(depth: 0)
          DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                           self.class.send(:recursive_content_content_a_query, depth:),
                                                                           {id:,
                                                                            depth: depth.to_i}
                                                                         ])}) content_contents").reorder(order_a: :asc)
        end

        class_methods do
          def recursive_content_links(depth: 0, preload: false)
            load_relation(
              relation_name: :content_content_a,
              scope: DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      recursive_content_links_query(depth:),
                                                                                      {id: current_scope.pluck(:id),
                                                                                       depth: depth.to_i}
                                                                                    ])}) content_contents").reorder(order_a: :asc),
              preload:
            )
          end

          def recursive_content_content_a(depth: 0, preload: false)
            load_relation(
              relation_name: :content_content_a,
              scope: DataCycleCore::ContentContent.from("(#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      recursive_content_content_a_query(depth:),
                                                                                      {id: current_scope.pluck(:id),
                                                                                       depth: depth.to_i}
                                                                                    ])}) content_contents").reorder(order_a: :asc),
              preload:
            )
          end

          private

          def recursive_content_links_query(depth: 0)
            if depth&.positive?
              leaf_select = <<-SQL.squish
                content_tree.depth + 1 >= :depth AS "leaf",
                CASE WHEN content_content_links.relation = 'overlay' THEN content_tree.depth ELSE content_tree.depth + 1 END AS "depth"
              SQL

              leaf_query = <<-SQL.squish
                AND NOT content_tree.leaf
              SQL

              depth_select = <<-SQL.squish
                , CASE WHEN content_content_links.relation = 'overlay' THEN 0 ELSE 1 END AS "depth"
              SQL
            else
              leaf_select = <<-SQL.squish
                FALSE AS "leaf"
              SQL
            end

            if depth == 1
              final_leaf_select = <<-SQL.squish
                content_content_links.relation != 'overlay' AS "leaf"
              SQL
            else
              final_leaf_select = <<-SQL.squish
                FALSE AS "leaf"
              SQL
            end

            recursive_subquery = <<-SQL.squish
              SELECT content_content_links.content_content_id,
                content_content_links.content_b_id,
                content_content_links.relation,
                #{leaf_select}
              FROM content_content_links
                INNER JOIN content_tree ON content_tree.content_b_id = content_content_links.content_a_id
              WHERE content_content_links.relation IS NOT NULL
            SQL

            recursive_subquery << leaf_query if leaf_query

            <<-SQL.squish
              WITH RECURSIVE content_tree(id, content_b_id, relation, leaf #{', depth' if depth&.positive?}) AS (
                SELECT content_content_links.content_content_id,
                  content_content_links.content_b_id,
                  content_content_links.relation,
                  #{final_leaf_select}
                  #{depth_select}
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
            if depth&.positive?
              leaf_select = <<-SQL.squish
                content_tree.depth + 1 >= :depth AS "leaf",
                CASE WHEN content_contents.relation_a = 'overlay' THEN content_tree.depth ELSE content_tree.depth + 1 END AS "depth"
              SQL

              leaf_query = <<-SQL.squish
                WHERE NOT content_tree.leaf
              SQL

              depth_select = <<-SQL.squish
                , CASE WHEN content_contents.relation_a = 'overlay' THEN 0 ELSE 1 END AS "depth"
              SQL
            else
              leaf_select = <<-SQL.squish
                FALSE AS "leaf"
              SQL
            end

            if depth == 1
              final_leaf_select = <<-SQL.squish
                content_contents.relation_a != 'overlay' AS "leaf"
              SQL
            else
              final_leaf_select = <<-SQL.squish
                FALSE AS "leaf"
              SQL
            end

            recursive_subquery = <<-SQL.squish
              SELECT content_contents.id,
              content_contents.content_b_id,
              content_contents.relation_a,
              #{leaf_select}
              FROM content_contents
                INNER JOIN content_tree ON content_tree.content_b_id = content_contents.content_a_id
            SQL

            recursive_subquery << leaf_query if leaf_query.present?

            <<-SQL.squish
              WITH RECURSIVE content_tree(id, content_b_id, relation_a, leaf #{', depth' if depth&.positive?}) AS (
                SELECT content_contents.id,
                  content_contents.content_b_id,
                  content_contents.relation_a,
                  #{final_leaf_select}
                  #{depth_select}
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
