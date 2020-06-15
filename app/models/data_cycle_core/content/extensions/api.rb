# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Api
        extend ActiveSupport::Concern

        def to_api_list
          {
            '@id' => id,
            '@type' => schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize,
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
            '@type' => schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize,
            'name' => title || template_name
          }
        end

        def api_type
          schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize
        end
      end
    end
  end
end
