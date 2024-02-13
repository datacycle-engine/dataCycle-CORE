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
          computed_types = computed_schema_types&.reject { |t| t.start_with?('dcls:') }
          return computed_types.first if computed_types&.size == 1

          computed_types.presence || schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize
        end

        def api_type
          api_types = computed_schema_types.presence || [try(:schema_type) || self.class.name.demodulize, 'dcls:' + template_name].flatten
          api_types << schema.dig('api', 'type') if schema.dig('api', 'type').present?
          api_types
        end
      end
    end
  end
end
