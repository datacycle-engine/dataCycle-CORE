# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_thing(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_system_sync', ->(s) { parse_external_systems(s, external_source_id) })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:reject_keys, ['id', 'external_source', 'external_source_id'])
          .>> t(:strip_all)
        end

        def self.parse_external_systems(data, external_source_id)
          data
            .dig('external_system_sync')
            .merge({
              'external_key' => s.dig('id'),
              'external_source_id' => external_source_id
            })
            .merge({
              'external_key' => s.dig('external_key'),
              'external_source_id' => DataCycleCore::ExternalSystem.find_by(identifier: s.dig('external_source'))
            })
        end
      end
    end
  end
end
