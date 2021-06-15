# frozen_string_literal: true

module DataCycleCore
  module MapHelper
    def additional_map_values(contents, paths)
      return if paths.blank? || contents.blank?

      Array.wrap(contents).map! { |c|
        child_keys = (paths.keys & (c.linked_property_names | c.embedded_property_names))

        next child_keys.map! { |ck| additional_map_values(c.try(ck)&.includes(:translations), paths[ck]) }.flatten.compact if child_keys.present?

        value_to_geojson(
          c.try(paths['geo'].to_s),
          {
            title: I18n.with_locale(c.first_available_locale) { c.try(paths['title'].to_s) },
            thingPath: thing_path(c),
            style: { color: 'gray', width: 4 }
          }
        )
      }.flatten.compact.uniq
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
