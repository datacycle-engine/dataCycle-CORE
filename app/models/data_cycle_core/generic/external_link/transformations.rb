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
            .>> t(:add_field, 'external_system_syncs', ->(s) { parse_identifier(s['identifier'], external_system_id) })
            .>> t(:strip_all)
        end

        def self.parse_identifier(data, external_system_id)
          data.filter_map { |d|
            {
              external_system_id:,
              external_key: d['value'],
              name: d['name'],
              alternate_name: d['alternateName']
            }
          }.select { |d| d[:external_key].present? }
        end
      end
    end
  end
end
