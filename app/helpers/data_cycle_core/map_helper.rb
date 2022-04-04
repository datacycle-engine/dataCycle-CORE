# frozen_string_literal: true

module DataCycleCore
  module MapHelper
    def additional_map_values(contents, paths, values = {}, key_prefix = nil)
      return values if paths.blank? || contents.blank?

      Array.wrap(contents).each do |c|
        child_keys = (paths.keys & (c.linked_property_names | c.embedded_property_names))

        if child_keys.present?
          child_keys.each do |ck|
            additional_map_values(c.try(ck)&.includes(:translations), paths[ck], values, [key_prefix, ck].compact.join('_'))
          end
        end

        next if paths['geo'].blank?

        values[key_prefix] ||= {
          type: 'FeatureCollection',
          features: []
        }

        feature = value_to_geojson(c.try(paths['geo'].to_s), geojson_properties(c, paths))

        (values[key_prefix][:features]).push(feature) unless feature.nil?
      end

      values
    end

    def geojson_properties(content, paths)
      {
        id: content.id,
        name: I18n.with_locale(content.first_available_locale) { content.try(paths['title'].to_s) },
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
      overlay_paths = definition&.dig('ui', 'edit', 'options', 'additional_values_overlay')

      return unless overlay_paths.present? && paths.present?

      paths = paths.slice(*overlay_paths) if overlay_paths.is_a?(::Array)

      paths.each_with_object({}) do |(k, v), a|
        value = v || {}
        value['definition'] = content.properties_for(k)

        next unless attribute_editable?(k, value['definition'], options, content) && value.dig('definition', 'type') == 'linked'

        value['label'] = translated_attribute_label(k, value['definition'], content, options)

        a[k] = value
      end
    end

    def additional_map_values_filter(tree_label)
      return {} if tree_label.blank?

      DataCycleCore::ClassificationAlias
        .includes(:classification_tree_label, :parent_classification_alias)
        .where(classification_tree_labels: { name: tree_label })
        .order(created_at: :asc)
        .group_by { |c| c.parent_classification_alias&.id }
    end
  end
end
