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

        values[key_prefix][:features].push(feature) unless feature.nil?
      end
      values.reject! { |_, v| v[:features].blank? }
      values
    end

    def geojson_properties(content, paths)
      {
        '@id': content.id,
        name: I18n.with_locale(content.first_available_locale) { content.try(paths['title'].to_s) },
        clickable: true
      }
    end

    def value_to_geojson(value, properties = {})
      return if value.blank?

      {
        type: 'Feature',
        geometry: RGeo::GeoJSON.encode(value),
        properties: properties.compact_blank.presence
      }.compact
    end

    def classification_polygon_properties(classification_polygon)
      {
        '@id': classification_polygon.id,
        classificationId: classification_polygon.classification_alias.id,
        name: classification_polygon.classification_alias.internal_name
      }
    end

    def classification_polygon_features(classification_alias)
      {
        classification_polygon: {
          type: 'FeatureCollection',
          features: classification_alias.classification_polygons.map do |p|
            value_to_geojson(p.geom, classification_polygon_properties(p))
          end
        }
      }.to_json
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

    def map_filter_layers(filters)
      filter_layers = {}
      filter_bbox = nil
      concept_ids = (
        Array.wrap(filters&.select { |f| f['q'] == 'geo_within_classification' && f['t'] == 'geo_filter' }&.pluck('v')&.flatten) +
        Array.wrap(filters&.select { |f| f['t'] == 'classification_alias_ids' }&.pluck('v')&.flatten)
      ).uniq

      if concept_ids.present?
        polygons = DataCycleCore::ClassificationPolygon.where(classification_alias_id: concept_ids)
        existing_concept_ids = polygons.pluck(:classification_alias_id)
        filter_bbox = polygons.to_bbox
        filter_layers['concept_ids'] = existing_concept_ids
      end

      if (geo_radius = filters&.select { |f| f['q'] == 'geo_radius' && f['t'] == 'geo_filter' }).present?
        filter_layers['geo_radius'] = geo_radius.pluck('v').flatten.uniq
      end

      return filter_layers, filter_bbox
    end
  end
end
