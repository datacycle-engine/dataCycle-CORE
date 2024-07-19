# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module External
        def with_external_system
          reflect(
            @query.where.not(thing[:external_source_id].eq(nil))
          )
        end

        def not_with_external_system
          reflect(
            @query.where(thing[:external_source_id].eq(nil))
          )
        end

        def external_source(ids = nil)
          return self if ids.blank?

          ids = ids.clone
          includes_nil = Array.wrap(ids).delete('nil').present?
          where_clause = thing[:external_source_id].in(ids)
          where_clause = where_clause.or(thing[:external_source_id].eq(nil)) if includes_nil

          reflect(
            @query.where(where_clause)
          )
        end

        def not_external_source(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(thing[:external_source_id].not_in(ids).or(thing[:external_source_id].eq(nil)))
          )
        end

        def external_system(ids = nil, type = 'import')
          return self if ids.blank?

          if type == 'import'
            return external_source(ids)
          elsif type == 'all'
            alias1 = "things_#{SecureRandom.hex(5)}"
            sub_query = <<-SQL.squish
              things.id IN (
                SELECT "ess"."syncable_id"
                FROM "external_system_syncs" "ess"
                WHERE "ess"."external_system_id" IN (:ids)
                UNION ALL
                SELECT "#{alias1}"."id"
                FROM "things" "#{alias1}"
                WHERE "#{alias1}"."external_source_id" IN (:ids)
              )
            SQL
          else
            sub_query = <<-SQL.squish
              things.id IN (
                SELECT "ess"."syncable_id"
                FROM "external_system_syncs" "ess"
                WHERE "ess"."external_system_id" IN (:ids)
                AND "ess"."sync_type" = :type
              )
            SQL
          end

          reflect(
            @query.where(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        sub_query,
                                        ids:,
                                        type:
                                      ])
            )
          )
        end

        def not_external_system(ids = nil, type = 'import')
          return self if ids.blank?

          if type == 'import'
            return not_external_source(ids)
          elsif type == 'all'
            alias1 = "things_#{SecureRandom.hex(5)}"
            sub_query = <<-SQL.squish
              things.id NOT IN (
                SELECT "ess"."syncable_id"
                FROM "external_system_syncs" "ess"
                WHERE "ess"."external_system_id" IN (:ids)
                UNION ALL
                SELECT "#{alias1}"."id"
                FROM "things" "#{alias1}"
                WHERE "#{alias1}"."external_source_id" IN (:ids)
              )
            SQL
          else
            sub_query = <<-SQL.squish
              things.id IN (
                SELECT "ess"."syncable_id"
                FROM "external_system_syncs" "ess"
                WHERE "ess"."external_system_id" IN (:ids)
                AND "ess"."sync_type" = :type
              )
            SQL
          end

          reflect(
            @query.where(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        sub_query,
                                        ids:,
                                        type:
                                      ])
            )
          )
        end
      end
    end
  end
end
