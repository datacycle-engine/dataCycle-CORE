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
            external_source(ids)
          elsif type == 'all'
            reflect(
              @query.where(
                external_system_sync.where(
                  external_system_sync[:external_system_id].in(ids)
                    .and(external_system_sync[:syncable_id].eq(thing[:id]))
                ).exists
                .or(thing[:external_source_id].in(ids))
              )
            )
          else
            reflect(
              @query.where(
                external_system_sync
                  .where(
                    external_system_sync[:external_system_id].in(ids)
                      .and(external_system_sync[:syncable_id].eq(thing[:id]))
                      .and(external_system_sync[:sync_type].eq(type))
                  ).exists
              )
            )
          end
        end

        def not_external_system(ids = nil, type = 'import')
          return self if ids.blank?

          if type == 'import'
            not_external_source(ids)
          elsif type == 'all'
            reflect(
              @query.where(
                external_system_sync.where(
                  external_system_sync[:external_system_id].in(ids)
                    .and(external_system_sync[:syncable_id].eq(thing[:id]))
                ).exists.not
                .and(thing[:external_source_id].not_in(ids).or(thing[:external_source_id].eq(nil)))
              )
            )
          else
            reflect(
              @query.where(
                external_system_sync
                  .where(
                    external_system_sync[:external_system_id].in(ids)
                    .and(external_system_sync[:syncable_id].eq(thing[:id]))
                    .and(external_system_sync[:sync_type].eq(type))
                  ).exists.not
              )
            )
          end
        end
      end
    end
  end
end
