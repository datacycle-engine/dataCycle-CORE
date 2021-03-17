# frozen_string_literal: true

module DataCycleCore
  module MapHelper
    def additional_map_values(contents, paths)
      return if paths.blank? || contents.blank?

      contents = Array.wrap(contents)

      contents.map! do |c|
        values = []

        if paths.is_a?(::Hash)
          paths.each do |k, v|
            values.push(additional_map_values(c.try(k), v))
          end
        elsif paths.is_a?(::Array)
          property_names = paths.dup
          geo_property_value = c.try(c.geo_properties.keys.map { |p| property_names.delete(p) }.compact.first.to_s)

          values.push(
            value_to_geojson(geo_property_value, property_names.map { |p| [p.camelize(:lower), I18n.with_locale(c.first_available_locale) { c.try(p) }] }.to_h.merge({ thingPath: thing_path(c) }))
          )
        end

        values.flatten.reject { |v| v.blank? || v[:geometry].blank? }
      end

      contents.flatten.compact
    end

    def value_to_geojson(value, properties = {})
      return if value.blank?

      {
        type: 'Feature',
        geometry: RGeo::GeoJSON.encode(value),
        properties: properties.presence
      }.compact
    end
  end
end
