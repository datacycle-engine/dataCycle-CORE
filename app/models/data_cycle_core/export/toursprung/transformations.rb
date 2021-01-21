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
            description: data&.title,
            data: content_data.reject { |_k, v| v.blank? }.to_json
          }

          if data.try(:tour).is_a?(RGeo::Geographic::SphericalLineStringImpl)
            json_data.merge({
              lat: data.try(:tour)&.points&.first&.y,
              lng: data.try(:tour)&.points&.first&.x,
              points: data.try(:tour)&.points&.map { |p| [p.y, p.x] }&.to_json
            })
          else
            json_data.merge({
              lat: data.location&.y,
              lng: data.location&.x
            })
          end
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
            data.translated_locales&.collect { |l| [l, I18n.with_locale(l) { data.try(key) }] }&.to_h&.reject { |_k, v| v.blank? }
          else
            data.try(:key)
          end
        end
      end
    end
  end
end
