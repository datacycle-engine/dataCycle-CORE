# frozen_string_literal: true

module DataCycleCore
  module Export
    module MediaArchive
      module Functions
        def self.transformations
          DataCycleCore::Export::Generic::Transformations
        end

        def self.update_person(utility_object:, data:, type:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: "update_#{type}",
            method: (external_system.config.dig('export_config', 'update', 'method') || external_system.config.dig('export_config', 'method') || :put).to_sym,
            transformation: external_system.config.dig('export_config', 'update', 'transformation') || external_system.config.dig('export_config', 'transformation') || :json_partial,
            path: "/api/v1/#{type}",
            utility_object: utility_object,
            locale: I18n.locale
          )

          DataCycleCore::Export::Generic::Functions.enqueue_webhook(data, webhook, external_system)
        end

        def self.delete_person(utility_object:, data:, type:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(
              id: data.id,
              template_name: data.template_name,
              webhook_data: OpenStruct.new(
                external_keys: data.external_keys_by_system_id(external_system.id),
                original_external_keys: data.try(:original)&.external_keys_by_system_id(external_system.id)
              ),
              original_id: data.original_id
            ),
            type: "delete_#{type}",
            method: (external_system.config.dig('export_config', 'delete', 'method') || external_system.config.dig('export_config', 'method') || :delete).to_sym,
            transformation: external_system.config.dig('export_config', 'delete', 'transformation') || external_system.config.dig('export_config', 'transformation') || :json_partial,
            path: utility_object.endpoint.path_transformation(data, external_system, 'delete', type),
            utility_object: utility_object,
            locale: I18n.locale
          )

          DataCycleCore::Export::Generic::Functions.enqueue_webhook(data, webhook, external_system)
        end
      end
    end
  end
end
