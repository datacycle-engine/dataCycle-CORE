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

        def to_api_default_values
          {
            '@id' => id,
            '@type' => schema.dig('api', 'type') || try(:schema_type) || self.class.name.demodulize,
            'name' => title
          }
        end
      end
    end
  end
end
