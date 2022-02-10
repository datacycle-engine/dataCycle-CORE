# frozen_string_literal: true

module DataCycleCore
  module MapHelper
    def additional_map_values(contents, paths)
      return if paths.blank? || contents.blank?

      Array.wrap(contents).map! { |c|
        child_keys = (paths.keys & (c.linked_property_names | c.embedded_property_names))

        next child_keys.map! { |ck| additional_map_values(c.try(ck)&.includes(:translations), paths[ck]) }.flatten.compact if child_keys.present?

        value_to_geojson(
          c.try(paths['geo'].to_s), geojson_properties(c, paths)
        )
      }.flatten.compact.uniq
    end

    def geojson_properties(content, paths)
      {
        title: I18n.with_locale(content.first_available_locale) { content.try(paths['title'].to_s) },
        id: content.id,
        thingPath: thing_path(content),
        style: { color: 'gray', width: 4 }
      }
    end

    def value_to_geojson(value, properties = {})
      return if value.blank?

      {
        type: 'Feature',
        geometry: RGeo::GeoJSON.encode(value),
        properties: properties.reject { |_, v| v.blank? }.presence
      }.compact
    end

    def additional_map_values_overlay(content, definition, options)
      paths = definition&.dig('ui', 'edit', 'options', 'additional_value_paths')

      return unless definition&.dig('ui', 'edit', 'options', 'additional_values_overlay').to_s == 'true' && paths.present?

      paths.each_with_object({}) do |(k, v), a|
        value = v || {}
        value['definition'] = content.properties_for(k)

        next unless attribute_editable?(k, value['definition'], options, content)

        value['label'] = translated_attribute_label(k, value['definition'], content, options)

        a[k] = value
      end
    end

    def additional_map_values_filter(tree_label)
      DataCycleCore::ClassificationAlias
        .includes(:classification_tree_label)
        .where(classification_trees: { parent_classification_alias_id: nil }, classification_tree_labels: { name: tree_label })
        .order(created_at: :asc)
    end
  end
end
