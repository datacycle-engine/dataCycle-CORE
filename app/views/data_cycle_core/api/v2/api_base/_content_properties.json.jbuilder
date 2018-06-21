# frozen_string_literal: true

unless content.schema.nil?

  ordered_validation_properties(validation: content.schema).each do |key, prop|
    next if options[:hidden_attributes].include?(key)
    value = content.try(key.to_sym)
    value = value.presence&.page&.per(DataCycleCore.linked_objects_page_size) if value.is_a?(ActiveRecord::Relation)

    json.render_attribute! key: key, definition: prop, value: value, parameters: { options: options }, content: content
  end

end
