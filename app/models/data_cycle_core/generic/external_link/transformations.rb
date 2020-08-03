# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ExternalLink
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::ExternalLink::Functions[*args]
        end

        def self.transformation
          t(:deep_stringify_keys)
          .>> t(:rename_keys, { '@id' => 'id' })
          .>> t(:reject_keys, ['@type'])
          .>> t(:add_field, 'external_system_syncs', ->(s) { parse_identifier(s.dig('identifier'), s.dig('data_cycle_external_system_id')) })
          .>> t(:strip_all)
        end

        def self.parse_identifier(data, external_source_id)
          result = data.map { |d|
            next unless DataCycleCore::ExternalSystem.find_by(name: d.dig('propertyID')).try(:id) == external_source_id
            {
              'external_system_id' => DataCycleCore::ExternalSystem.find_by(name: d.dig('propertyID')).try(:id),
              'external_key' => d.dig('value')
            }
          }.select { |d| d['external_key'].present? && d['external_system_id'].present? }
          result
        end
      end
    end
  end
end
