# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Id
        def like_id(key = nil, type = 'all')
          return self if (key_string = key&.dig('text').to_s).blank?

          key_string = "%#{key_string}%"

          case type
          when 'internal'
            sub_query = '"things"."id"::VARCHAR ILIKE :key_string'
          when 'external'
            sub_query = external_subquery('ILIKE')
          when 'all'
            sub_query = all_subquery('ILIKE', true, '::VARCHAR') # always treat as uuid to allow partial matching
          end

          reflect(
            @query.where(sanitize_sql([sub_query, { key_string: }]))
          )
        end

        def id(key = nil, type = 'all')
          return self if (key_string = key&.dig('text').to_s).blank?

          case type
          when 'internal'
            sub_query = if key_string.uuid?
                          '"things"."id" = :key_string'
                        else
                          '1 = 0'
                        end
          when 'external'
            sub_query = external_subquery('=')
          when 'all'
            sub_query = all_subquery('=', key_string.uuid?)
          end

          reflect(
            @query.where(sanitize_sql([sub_query, { key_string: }]))
          )
        end

        private

        def external_subquery(operator = '=')
          alias1 = "th#{SecureRandom.hex(5)}"

          <<~SQL.squish
            "things"."id" IN (
              SELECT "ess"."syncable_id"
              FROM "external_system_syncs" "ess"
              WHERE "ess"."external_key" #{operator} :key_string
              UNION ALL
              SELECT "#{alias1}"."id"
              FROM "things" "#{alias1}"
              WHERE "#{alias1}"."external_key" #{operator} :key_string
            )
          SQL
        end

        def all_subquery(operator = '=', is_uuid = false, id_cast = '')
          alias1 = "th#{SecureRandom.hex(5)}"
          alias2 = "th#{SecureRandom.hex(5)}"

          base_query = <<~SQL.squish
            SELECT "ess"."syncable_id"
            FROM "external_system_syncs" "ess"
            WHERE "ess"."external_key" #{operator} :key_string
            UNION ALL
            SELECT "#{alias1}"."id"
            FROM "things" "#{alias1}"
            WHERE "#{alias1}"."external_key" #{operator} :key_string
          SQL

          if is_uuid
            base_query.concat(' ').concat(<<~SQL.squish)
              UNION ALL
              SELECT "#{alias2}"."id"
              FROM "things" "#{alias2}"
              WHERE "#{alias2}"."id"#{id_cast} #{operator} :key_string
            SQL
          end

          <<~SQL.squish
            "things"."id" IN (
              #{base_query}
            )
          SQL
        end
      end
    end
  end
end
