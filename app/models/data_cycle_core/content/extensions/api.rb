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
            'dct:created' => created_at
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

        def api_type
          [schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize, 'dcls:' + template_name].flatten
        end
      end
    end
  end
end
