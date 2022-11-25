# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Id
        def id(key = nil, type = 'all')
          return self if key.blank? || key.dig('text').blank?
          key_string = key.dig('text')
          if type == 'internal'
            reflect(
              @query.where(cast(thing[:id], 'TEXT').matches(key_string))
            )
          elsif type == 'external'
            reflect(
              @query
                .where(
                  external_system_sync.where(
                    external_system_sync[:syncable_id].eq(thing[:id])
                    .and(external_system_sync[:external_key].eq(key_string))
                  ).exists
                  .or(thing[:external_key].eq(key_string))
                )
            )
          elsif type == 'all'
            reflect(
              @query
                .where(
                  external_system_sync.where(
                    external_system_sync[:syncable_id].eq(thing[:id])
                    .and(external_system_sync[:external_key].eq(key_string))
                  ).exists
                  .or(thing[:external_key].eq(key_string))
                  .or(cast(thing[:id], 'TEXT').matches(key_string))
                )
            )
          end
        end
      end
    end
  end
end
