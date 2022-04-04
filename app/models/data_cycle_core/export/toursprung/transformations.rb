# frozen_string_literal: true

module DataCycleCore
  module Export
    module Toursprung
      module Transformations
        def self.json_partial(utility_object, data)
          content_data = {}
          utility_object.external_system.export_config&.dig(:transformation_config, 'attributes', data&.template_name)&.each do |key|
            content_data[key.to_sym] = transform_attribute(data, key)
          end
          content_data.merge!(additional_attributes(utility_object, data) || {})

          json_data = {
            resource: utility_object.external_system.credentials(:export).dig('resources', data.template_name),
            id: data.id,
            description: I18n.with_locale(data&.first_available_locale) { data&.title },
            data: content_data.reject { |_k, v| v.blank? }.to_json
          }

          line_property_key = data&.geo_properties&.select { |_, v| v&.dig('ui', 'edit', 'type') == 'LineString' }&.keys&.first
          point_property_key = data&.geo_properties&.select { |_, v| v&.dig('ui', 'edit', 'type') != 'LineString' }&.keys&.first

          if point_property_key.present?
            json_data[:lat] = data.try(point_property_key)&.y
            json_data[:lng] = data.try(point_property_key)&.x
          end

          if line_property_key.present?
            json_data[:lat] = data.try(line_property_key)&.geometry_type.to_s.include?('MultiLineString') ? data.try(line_property_key)&.first&.points&.first&.y : data.try(line_property_key)&.points&.first&.y
            json_data[:lng] = data.try(line_property_key)&.geometry_type.to_s.include?('MultiLineString') ? data.try(line_property_key)&.first&.points&.first&.x : data.try(line_property_key)&.points&.first&.x
            json_data[:geojson] = RGeo::GeoJSON.encode(data.try(line_property_key))&.to_json
          end

          json_data.compact!

          json_data[:is_enabled] = 0 if !json_data.key?(:lat) && !json_data.key?(:lng) && !json_data.key?(:geojson)

          json_data
        end

        def self.delete_json_partial(utility_object, data)
          {
            resource: utility_object.external_system.credentials(:export).dig('resources', data.template_name),
            id: data.id
          }
        end

        def self.additional_attributes(_utility_object, _data)
          nil
        end

        def self.transform_attribute(data, key)
          if data&.translatable_property_names&.include?(key.to_s)
            data.translated_locales&.index_with { |l| I18n.with_locale(l) { data.try(key) } }&.reject { |_k, v| v.blank? }
          else
            data.try(:key)
          end
        end
      end
    end
  end
end
