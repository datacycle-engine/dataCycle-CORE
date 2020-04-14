# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Functions
        include Transformations

        def self.transformations
          DataCycleCore::Export::Generic::Transformations
        end

        def self.create(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = DataCycleCore::Export::Generic::Webhook.new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: :create,
            method: external_system.config.dig('push_config', __method__.to_s, 'method') || external_system.config.dig('push_config', 'method') || :post,
            transformation: external_system.config.dig('push_config', __method__.to_s, 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: external_system.config.dig('push_config', __method__.to_s, 'path') || external_system.config.dig('push_config', 'path') || '/create',
            utility_object: utility_object,
            locale: I18n.locale
          )

          return if Delayed::Job.exists?(queue: 'webhooks', delayed_reference_type: webhook.reference_type, delayed_reference_id: data.id, locked_at: nil)

          data.add_external_system_data(external_system, nil, 'pending')
          Delayed::Job.enqueue(webhook)
        end

        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = DataCycleCore::Export::Generic::Webhook.new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: :update,
            method: external_system.config.dig('push_config', __method__.to_s, 'method') || external_system.config.dig('push_config', 'method') || :post,
            transformation: external_system.config.dig('push_config', __method__.to_s, 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: external_system.config.dig('push_config', __method__.to_s, 'path') || external_system.config.dig('push_config', 'path') || '/update',
            utility_object: utility_object,
            locale: I18n.locale
          )

          return if Delayed::Job.exists?(queue: 'webhooks', delayed_reference_type: webhook.reference_type, delayed_reference_id: data.id, locked_at: nil)

          data.add_external_system_data(external_system, nil, 'pending')
          Delayed::Job.enqueue(webhook)
        end

        def self.delete(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = DataCycleCore::Export::Generic::Webhook.new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: :delete,
            method: external_system.config.dig('push_config', __method__.to_s, 'method') || external_system.config.dig('push_config', 'method') || :delete,
            transformation: external_system.config.dig('push_config', __method__.to_s, 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: external_system.config.dig('push_config', __method__.to_s, 'path') || external_system.config.dig('push_config', 'path') || '/delete',
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
