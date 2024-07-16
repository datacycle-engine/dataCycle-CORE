# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Id
        def id(key = nil, type = 'all')
          return self if (key_string = key&.dig('text').to_s).blank?

          case type
          when 'internal'
            if key_string.uuid?
              sub_query = '"things"."id" = :key_string'
            else
              sub_query = '1 = 0'
            end
          when 'external'
            alias1 = "things_#{SecureRandom.hex(5)}"
            sub_query = <<-SQL.squish
              things.id IN (
                SELECT "ess"."syncable_id"
                FROM "external_system_syncs" "ess"
                WHERE "ess"."external_key" = :key_string
                UNION ALL
                SELECT "#{alias1}"."id"
                FROM "things" "#{alias1}"
                WHERE "#{alias1}"."external_key" = :key_string
              )
            SQL
          when 'all'
            alias1 = "things_#{SecureRandom.hex(5)}"
            alias2 = "things_#{SecureRandom.hex(5)}"

            base_query = <<-SQL.squish
              SELECT "ess"."syncable_id"
              FROM "external_system_syncs" "ess"
              WHERE "ess"."external_key" = :key_string
              UNION ALL
              SELECT "#{alias1}"."id"
              FROM "things" "#{alias1}"
              WHERE "#{alias1}"."external_key" = :key_string
            SQL

            if key_string.uuid?
              base_query.concat(' ').concat(<<-SQL.squish)
                UNION ALL
                SELECT "#{alias2}"."id"
                FROM "things" "#{alias2}"
                WHERE "#{alias2}"."id" = :key_string
              SQL
            end

            sub_query = <<-SQL.squish
              things.id IN (
                #{base_query}
              )
            SQL
          end

          reflect(
            @query.where(ActiveRecord::Base.send(:sanitize_sql_array, [
                                                   sub_query,
                                                   key_string:
                                                 ]))
          )
        end
      end
    end
  end
end
