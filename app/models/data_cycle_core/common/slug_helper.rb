# frozen_string_literal: true

module DataCycleCore
  module Common
    module SlugHelper
      extend ActiveSupport::Concern

      def first_free_number(base_slug)
        id_constraint = id.present? ? "AND c2.id <> '#{id}'" : ''
        sql = <<~SQL.squish
          SELECT MIN(COALESCE(SUBSTRING(collections.slug FROM '-(\\d+)?$')::INTEGER, 0)) + 1
          FROM collections
          WHERE collections.slug ~ :slug_regex
            AND NOT EXISTS (
              SELECT 1
              FROM collections c2
              WHERE c2.slug = regexp_replace(collections.slug, '-\\d*$', '') || '-' || (
                  COALESCE(SUBSTRING(collections.slug FROM '-(\\d+)?$')::INTEGER, 0) + 1
                )::TEXT
                AND c2.id <> collections.id
                #{id_constraint}
            );
        SQL

        ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.send(:sanitize_sql_array, [sql, { slug_regex: "^#{base_slug}(-\\d+)?$" }])
        ).rows.first.first
      end
    end
  end
end
