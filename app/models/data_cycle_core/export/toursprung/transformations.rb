# frozen_string_literal: true

module DataCycleCore
  module Export
    module Toursprung
      module Transformations
        def self.json_partial(utility_object, data)
          api_version = utility_object.external_system.credentials.dig('api_version') || DataCycleCore.main_config.dig('api', 'default')

          content_json =
            if data.is_a?(DataCycleCore::Thing)
              "DataCycleCore::Api::#{api_version.classify}::ContentsController".safe_constantize&.render(
              assigns: try("common_data_#{api_version}", utility_object, data),
              template: "data_cycle_core/api/#{api_version}/contents/show",
              layout: false
            )
            else
              {}
            end

          {
            resource: utility_object.external_system.credentials.dig('resource'),
            id: data.id,
            lat: data.tour&.points&.first&.y,
            lng: data.tour&.points&.first&.x,
            points: data.tour&.points&.map { |p| [p.y, p.x] }&.to_json,
            data: content_json
          }
        end

        def self.common_data_v4(utility_object, data)
          {
            content: data,
            id: data.id,
            api_version: '4',
            language: data.try(:translated_locales)&.map(&:to_s) || [I18n.locale.to_s],
            include_parameters: utility_object.external_system.config.dig('push_config', name.demodulize.underscore, 'include_parameters') || utility_object.external_system.config.dig('push_config', 'include_parameters') || [],
            fields_parameters: utility_object.external_system.config.dig('push_config', name.demodulize.underscore, 'fields_parameters') || utility_object.external_system.config.dig('push_config', 'fields_parameters') || [],
            token: utility_object.external_system.credentials.dig('token')
          }
        end
      end
    end
  end
end
