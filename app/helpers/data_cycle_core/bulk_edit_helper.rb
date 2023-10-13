# frozen_string_literal: true

module DataCycleCore
  module BulkEditHelper
    def generic_content(watch_list)
      DataCycleCore::Thing.new(
        id: SecureRandom.uuid,
        thing_template: DataCycleCore::ThingTemplate.new(
          template_name: 'Generic',
          schema: {
            name: 'Generic',
            type: 'object',
            schema_type: 'Generic',
            content_type: 'entity',
            features: watch_list.things.shared_template_features,
            properties: watch_list.things.shared_ordered_properties(current_user)
          }.deep_stringify_keys!
        )
      )
    end
  end
end
