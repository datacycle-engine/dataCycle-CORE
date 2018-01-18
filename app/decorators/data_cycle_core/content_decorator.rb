class DataCycleCore::ContentDecorator < SimpleDelegator
  def self.special_property_names
    ['external_source_id', 'external_key']
  end

  def property_definitions
    metadata['validation']['properties']
  end

  def property_names
    property_definitions.reject { |k, v| v['type'].starts_with?('classification') || v['storage_location'] == 'key' }.keys
  end

  def linked_property_names
    linked_object_definitions.keys
  end

  def plain_property_names
    property_names - linked_property_names - embedded_object_names
  end

  def property_value(property_key)
    definition = property_definitions[property_key]

    if definition['storage_location'] == 'column' || definition['storage_location'] == 'key'
      __getobj__.send(property_key)
    else
      __getobj__.send(definition['storage_location'])[property_key]
    end
  end

  def translated_property_value(property_key, locale)
    definition = property_definitions[property_key]

    if definition['storage_location'] == 'column' || definition['storage_location'] == 'key'
      translations.find { |t| t.locale == locale }.send(property_key)
    else
      translations.find { |t| t.locale == locale }.send(definition['storage_location'])[property_key]
    end
  end

  def embedded_object_names
    property_definitions.select { |k, v| v['type'] == 'object' }.keys
  end

  def linked_object_definitions
    metadata['validation']['properties']
      .select { |k, v| v['type'].starts_with?('embedded') }
      .reject { |k, v| v['type_name'] == 'external_sources' }
  end

  def linked_object_data(key)
    definition = property_definitions[key]

    if definition['storage_location'] == 'column'
      send(key)
    else
      send(definition['storage_location'])[key]
    end
  end
end
