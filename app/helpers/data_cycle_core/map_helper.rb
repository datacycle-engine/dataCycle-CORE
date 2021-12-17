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
  end
end
