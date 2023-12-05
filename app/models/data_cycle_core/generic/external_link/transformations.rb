# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ExternalLink
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::ExternalLink::Functions[*args]
        end

        def self.transformation(external_system_id)
          t(:deep_stringify_keys)
          .>> t(:rename_keys, { '@id' => 'id' })
          .>> t(:reject_keys, ['@type'])
          .>> t(:add_field, 'external_system_syncs', ->(s) { parse_identifier(s.dig('identifier'), external_system_id) })
          .>> t(:strip_all)
        end

        def self.parse_identifier(data, external_system_id)
          result = data.map { |d|
            {
              external_system_id:,
              external_key: d.dig('value'),
              name: d.dig('name'),
              alternate_name: d.dig('alternateName')
            }
          }.compact.select { |d| d[:external_key].present? }

          result
        end
      end
    end
  end
end
