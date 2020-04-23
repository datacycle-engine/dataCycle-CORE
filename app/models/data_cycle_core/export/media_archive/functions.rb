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
          webhook = (external_system.config.dig('push_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: "update_#{type}",
            method: (external_system.config.dig('push_config', 'update', 'method') || external_system.config.dig('push_config', 'method') || :put).to_sym,
            transformation: external_system.config.dig('push_config', 'update', 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: "/api/v1/#{type}",
            utility_object: utility_object,
            locale: I18n.locale
          )

          return if Delayed::Job.exists?(queue: 'webhooks', delayed_reference_type: webhook.reference_type, delayed_reference_id: data.id, locked_at: nil)

          data.add_external_system_data(external_system, nil, 'pending')
          Delayed::Job.enqueue(webhook)
        end
      end
    end
  end
end
