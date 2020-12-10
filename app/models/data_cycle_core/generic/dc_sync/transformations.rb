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
          .>> t(:transform_embedded, external_source_id)
          .>> t(:reject_keys, ['external_source', 'external_source_id', 'external_system_syncs'])
          .>> t(:strip_all)
        end

        def self.parse_external_systems(data)
          [
            data.dig('external_system_syncs'),
            { 'external_key' => data.dig('external_key'), 'name' => data.dig('external_source') }
          ].flatten
        end
      end
    end
  end
end
