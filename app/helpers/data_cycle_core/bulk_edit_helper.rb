# frozen_string_literal: true

module DataCycleCore
  module BulkEditHelper
    def generic_content(features, properties)
      DataCycleCore::Thing.new(
        id: SecureRandom.uuid,
        schema: {
          name: 'Generic',
          type: 'object',
          schema_type: 'Generic',
          content_type: 'entity',
          features: features,
          properties: properties
        }.deep_stringify_keys!
      )
    end
  end
end
