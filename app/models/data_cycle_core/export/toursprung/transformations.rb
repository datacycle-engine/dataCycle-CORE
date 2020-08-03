# frozen_string_literal: true

module DataCycleCore
  module Export
    module Toursprung
      module Transformations
        def self.json_partial(utility_object, data)
          content_data = {}
          content_data[:name] = data.translated_locales&.collect { |l| [l, I18n.with_locale(l) { data.try(:name) }] }&.to_h&.reject { |_k, v| v.blank? }
          content_data[:text] = data.translated_locales&.collect { |l| [l, I18n.with_locale(l) { data.try(:text) }] }&.to_h&.reject { |_k, v| v.blank? }

          {
            resource: utility_object.external_system.credentials(:export).dig('resource'),
            id: data.id,
            lat: data.try(:tour)&.points&.first&.y,
            lng: data.try(:tour)&.points&.first&.x,
            points: data.try(:tour)&.points&.map { |p| [p.y, p.x] }&.to_json,
            data: content_data.compact.to_json
          }
        end
      end
    end
  end
end
