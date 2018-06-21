# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  json.set! key.pluralize.camelize(:lower) do
    json.array!(value.presence&.includes(:translations)) do |object|
      I18n.with_locale(object.first_available_locale) do
        if object.schema.present?

          json.content_partial! 'context', content: object
          ordered_validation_properties(validation: object.schema).each do |key, prop|
            object_value = object.try(key.to_sym)
            object_value = object_value.presence&.includes(:translations)&.page&.per(DataCycleCore.linked_objects_page_size) if object_value.is_a?(ActiveRecord::Relation) && prop['type'] == 'object'

            json.render_attribute! key: key, definition: prop, value: object_value, parameters: { options: options }, content: object
          end
        end
      end
    end
  end
end
