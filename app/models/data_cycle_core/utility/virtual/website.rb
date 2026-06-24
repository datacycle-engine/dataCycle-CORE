# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Website
        class << self
          # Generates a slugified path by traversing parent webpages via 'linked_thing', 'submenu', and 'main_menu' relations.
          # Uses a recursive CTE to build the path from the current webpage up to the parent Website.
          #
          # @param content [DataCycleCore::Thing] The webpage content to generate the path for
          # @return [String, nil] The slugified path (e.g., '/parent/child/page') or nil if not found
          # @example YAML schema configuration
          #   :dc_slugified_path:
          #     :type: string
          #     :virtual:
          #       :module: Website
          #       :method: slugified_path
          def slugified_path(content:, **_args)
            sql = <<~SQL.squish
              WITH recursive base AS (
                SELECT cc.content_a_id,
                  cc.relation_a AS relation,
                  ARRAY [cc.content_b_id] AS "path",
                  ARRAY [cc.content_b_id] AS "webpages"
                FROM content_contents cc
                WHERE cc.content_b_id = ?
                  AND cc.relation_a = 'linked_thing'
                UNION
                SELECT cc.content_a_id,
                  cc.relation_a AS relation,
                  base."path" || ARRAY [cc.content_b_id] AS "path",
                  ARRAY [cc2.content_b_id] ||base."webpages" AS "webpages"
                FROM content_contents cc
                  JOIN base ON base.content_a_id = cc.content_b_id
                  LEFT OUTER JOIN content_contents cc2 ON cc2.content_a_id = cc.content_a_id
                  AND cc2.relation_a = 'linked_thing'
                WHERE cc.relation_a IN ('submenu', 'main_menu')
                  AND cc.content_a_id <> ALL(base."path")
              )
              SELECT base.content_a_id AS id,
                array_remove("webpages", NULL) AS "webpages"
              FROM base
                JOIN things ON things.id = base.content_a_id
              WHERE things.template_name = 'Website'
            SQL

            sanitized_sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, content.id])
            path_ids = ActiveRecord::Base.connection.select_all(sanitized_sql).cast_values.first
            return if path_ids.nil?

            ancestors = DataCycleCore::Thing.where(id: path_ids.flatten.uniq, template_name: 'Webpage').preload(:translations).index_by(&:id)
            full_path = Array.wrap(path_ids[0]) + Array.wrap(path_ids[1])
            path = []

            full_path.each do |id|
              thing = ancestors[id]
              next if thing.nil?

              path << thing.try(:name)&.to_slug
            end

            path.compact_blank.join('/').prepend('/')
          rescue ActiveRecord::RecordNotFound
            nil
          end
        end
      end
    end
  end
end
