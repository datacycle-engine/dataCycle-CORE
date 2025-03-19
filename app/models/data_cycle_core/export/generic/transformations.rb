# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Transformations
        def self.json_partial(utility_object, data)
          api_version = utility_object.external_system.credentials(:export)['api_version'] || DataCycleCore.main_config.dig('api', 'default')
          renderer = "DataCycleCore::ApiRenderer::ThingRenderer#{api_version.classify}".safe_constantize&.new(
            contents: data,
            template: "data_cycle_core/api/#{api_version}/webhooks/default",
            **try("common_data_#{api_version}", utility_object, data)
          )
          renderer.render(:json)
        end

        def self.common_data_v4(utility_object, data)
          {
            content: data,
            id: data.id,
            language: I18n.available_locales.map(&:to_s),
            include_parameters: utility_object.external_system.config.dig('export_config', name.demodulize.underscore, 'include_parameters') || utility_object.external_system.config.dig('export_config', 'include_parameters') || [],
            fields_parameters: utility_object.external_system.config.dig('export_config', name.demodulize.underscore, 'fields_parameters') || utility_object.external_system.config.dig('export_config', 'fields_parameters') || [],
            additional_params: {
              token: (utility_object.external_system.credentials(:export)['token_type'] || 'body') == 'body' ? utility_object.external_system.credentials(:export)['token'] : nil
            }
          }
        end
      end
    end
  end
end
