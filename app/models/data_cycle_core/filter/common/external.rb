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
          return external_source(ids) if type == 'import'

          # this query performs well in all possible cases, things.id in (subquery) is worse in some cases with sorting (random)
          if type == 'all'
            reflect(
              @query.where(
                DataCycleCore::ExternalSystemSync
                  .where(external_system_id: ids)
                  .where(external_system_sync[:syncable_id].eq(thing[:id]))
                  .select(1)
                  .arel.exists
              ).or(
                @query.where(external_source_id: ids)
              )
            )
          else
            reflect(
              @query.where(
                DataCycleCore::ExternalSystemSync
                  .where(external_system_id: ids)
                  .where(sync_type: type)
                  .where(external_system_sync[:syncable_id].eq(thing[:id]))
                  .select(1)
                  .arel.exists
              )
            )
          end
        end

        def not_external_system(ids = nil, type = 'import')
          return self if ids.blank?
          return not_external_source(ids) if type == 'import'

          # this query performs well in all possible cases, things.id in (subquery) is worse in some cases with sorting (random)
          if type == 'all'
            reflect(
              @query
                .where.not(external_source_id: ids)
                .or(@query.where(external_source_id: nil))
                .where.not(
                  DataCycleCore::ExternalSystemSync
                  .where(external_system_id: ids)
                  .where(external_system_sync[:syncable_id].eq(thing[:id]))
                  .select(1)
                  .arel.exists
                )
            )
          else
            reflect(
              @query.where.not(
                DataCycleCore::ExternalSystemSync
                  .where(external_system_id: ids)
                  .where(sync_type: type)
                  .where(external_system_sync[:syncable_id].eq(thing[:id]))
                  .select(1)
                  .arel.exists
              )
            )
          end
        end
      end
    end
  end
end
