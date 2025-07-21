# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Api
        def to_api_list
          {
            '@id' => id,
            '@type' => api_type,
            'dct:modified' => updated_at,
            'dct:created' => created_at,
            'dc:touched' => cache_valid_since
          }
        end

        def to_api_deleted_list
          {
            '@id' => thing_id,
            'dct:deleted' => deleted_at
          }
        end

        def to_api_default_values
          {
            '@id' => id,
            '@type' => api_type
          }
        end

        def legacy_api_type
          computed_types = api_schema_types&.reject { |t| t.start_with?('dcls:') }
          return computed_types.first if computed_types&.size == 1

          computed_types.presence || schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize
        end

        def api_type
          api_types = api_schema_types.presence || [try(:schema_type) || self.class.name.demodulize, "dcls:#{template_name}"].flatten
          api_types.concat(Array.wrap(schema.dig('api', 'type'))).uniq! if schema.dig('api', 'type').present?
          api_types
        end

        def external_syncs_as_property_values
          external_connections_hash = []

          if external?
            external_connections_hash << {
              '@type' => 'PropertyValue',
              'propertyID' => external_source.identifier,
              'value' => external_key,
              'valueReference' => 'import'
            }
          end

          external_system_syncs.includes(:external_system).find_each do |system_data|
            next if system_data.external_key.blank?

            external_connections_hash << {
              '@type' => 'PropertyValue',
              'propertyID' => system_data.external_system.identifier,
              'value' => system_data.external_key,
              'valueReference' => system_data.sync_type
            }
          end

          external_connections_hash
        end
      end
    end
  end
end
