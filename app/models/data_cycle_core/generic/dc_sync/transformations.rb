# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::DcSync::TransformationFunctions[*args]
        end

        def self.to_thing(external_source_id)
          t(:stringify_keys)
          .>> t(:create_main_thing, external_source_id)
          .>> t(:add_field, 'external_system_data', ->(s) { parse_external_systems(s) })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:reject_keys, ['external_source', 'external_source_id', 'external_system_syncs', 'include_translation'])
          .>> t(:strip_all)
        end

        def self.parse_external_systems(data)
          syncs = data.dig('external_system_syncs')
          if data.dig('external_source').present?
            syncs += [{
              'external_key' => data.dig('external_key'),
              'name' => data.dig('external_source'),
              'identifier' => data.dig('external_source'),
              'status' => 'success',
              'last_sync_at' => data.dig('updated_at'),
              'last_successful_sync_at' => data.dig('updated_at'),
              'sync_type' => data.dig('sync_type') || 'duplicate'
            }]
          end
          syncs&.flatten
        end
      end
    end
  end
end
