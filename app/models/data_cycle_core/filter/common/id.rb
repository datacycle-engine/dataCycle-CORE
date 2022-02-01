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

# @query.where(external_system_sync.where(external_system_sync[:external_key].eq(key_string).and(external_system_sync[:syncable_id].eq(thing[:id]))).exists.or(thing[:external_key].matches(key_string)))
#
#
# SELECT things.*
# FROM things
# WHERE things.template = FALSE
# AND things.content_type != 'embedded'
# AND EXISTS (
#   SELECT 1 FROM searches WHERE
#     (searches.content_data_id = things.id)
#     AND searches.locale = 'de'
# )
# AND (
#   EXISTS (
#     SELECT FROM external_system_syncs WHERE external_system_syncs.external_key = 'Bergfex - Skigebiet - 1177'
#     AND external_system_syncs.syncable_id = things.id
#   ) OR things.external_key ILIKE 'Bergfex - Skigebiet - 1177')
# ORDER BY things.boost DESC, things.updated_at DESC, things.id DESC
