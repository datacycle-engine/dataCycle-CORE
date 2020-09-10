# frozen_string_literal: true

module DataCycleCore
  module Export
    module Toursprung
      module Transformations
        def self.json_partial(utility_object, data)
          content_data = {}
          content_data[:name] = data.translated_locales&.collect { |l| [l, I18n.with_locale(l) { data.try(:name) }] }&.to_h&.reject { |_k, v| v.blank? }
          content_data[:text] = data.translated_locales&.collect { |l| [l, I18n.with_locale(l) { data.try(:text) }] }&.to_h&.reject { |_k, v| v.blank? }
          content_data[:specificTypes] = specific_types(utility_object, data)

          json_data = {
            resource: utility_object.external_system.credentials(:export).dig('resources', data.template_name),
            id: data.id,
            data: content_data.compact.to_json
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

        def self.specific_types(utility_object, data)
          return if utility_object.external_system.credentials(:export).dig('specific_types_tree_label').blank?

          data.mapped_classification_aliases.for_tree(utility_object.external_system.credentials(:export).dig('specific_types_tree_label')).map do |ca|
            ca.translated_locales.map { |l|
              I18n.with_locale(l) { [l, ca.name] }
            }.to_h&.reject { |_k, v| v.blank? }
          end
        end
      end
    end
  end
end
