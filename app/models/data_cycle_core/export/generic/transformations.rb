# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Transformations
        def self.json_partial(utility_object, data)
          api_version = utility_object.external_system.credentials(:export)['api_version'] || DataCycleCore.main_config.dig('api', 'default')

          "DataCycleCore::Api::#{api_version.classify}::ContentsController".safe_constantize&.render(
            assigns: try("common_data_#{api_version}", utility_object, data),
            template: "data_cycle_core/api/#{api_version}/webhooks/default",
            layout: false
          )
        end

        def self.common_data_v4(utility_object, data)
          {
            content: data,
            id: data.id,
            api_version: '4',
            api_context: 'api',
            language: I18n.available_locales.map(&:to_s),
            include_parameters: utility_object.external_system.config.dig('export_config', name.demodulize.underscore, 'include_parameters') || utility_object.external_system.config.dig('export_config', 'include_parameters') || [],
            fields_parameters: utility_object.external_system.config.dig('export_config', name.demodulize.underscore, 'fields_parameters') || utility_object.external_system.config.dig('export_config', 'fields_parameters') || [],
            field_filter: (utility_object.external_system.config.dig('export_config', name.demodulize.underscore, 'fields_parameters') || utility_object.external_system.config.dig('export_config', 'fields_parameters')).present?,
            token: (utility_object.external_system.credentials(:export)['token_type'] || 'body') == 'body' ? utility_object.external_system.credentials(:export)['token'] : nil,
            permitted_params: {}
          }
        end
      end
    end
  end
end
