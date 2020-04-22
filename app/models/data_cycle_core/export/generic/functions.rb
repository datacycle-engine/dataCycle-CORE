# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Functions
        include Transformations

        def self.transformations
          DataCycleCore::Export::Generic::Transformations
        end

        def self.filter(data:, external_system:, method_name:)
          template_names = Array.wrap(external_system.config.dig('push_config', method_name, 'filter', 'template_names') || external_system.config.dig('push_config', 'filter', 'template_names'))
          classification_ids = Array.wrap(external_system.config.dig('push_config', method_name, 'filter', 'classifications') || external_system.config.dig('push_config', 'filter', 'classifications')).map { |f| DataCycleCore::ClassificationAlias.classification_for_tree_with_name(f['tree_label'], f['aliases']) }

          (template_names.present? ? data.template_name.in?(template_names) : true) && (classification_ids.present? ? classification_ids.all? { |c| data.classifications.map(&:id).include?(c) } : true)
        end

        def self.create(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('push_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: :create,
            method: (external_system.config.dig('push_config', __method__.to_s, 'method') || external_system.config.dig('push_config', 'method') || :post).to_sym,
            transformation: external_system.config.dig('push_config', __method__.to_s, 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: format(external_system.config.dig('push_config', __method__.to_s, 'path') || external_system.config.dig('push_config', 'path') || '/create', id: data&.id),
            utility_object: utility_object,
            locale: I18n.locale
          )

          return if Delayed::Job.exists?(queue: 'webhooks', delayed_reference_type: webhook.reference_type, delayed_reference_id: data.id, locked_at: nil)

          data.add_external_system_data(external_system, nil, 'pending')
          Delayed::Job.enqueue(webhook)
        end

        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('push_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: :update,
            method: (external_system.config.dig('push_config', __method__.to_s, 'method') || external_system.config.dig('push_config', 'method') || :put).to_sym,
            transformation: external_system.config.dig('push_config', __method__.to_s, 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: format(external_system.config.dig('push_config', __method__.to_s, 'path') || external_system.config.dig('push_config', 'path') || '/update', id: data&.id),
            utility_object: utility_object,
            locale: I18n.locale
          )

          return if Delayed::Job.exists?(queue: 'webhooks', delayed_reference_type: webhook.reference_type, delayed_reference_id: data.id, locked_at: nil)

          data.add_external_system_data(external_system, nil, 'pending')
          Delayed::Job.enqueue(webhook)
        end

        def self.delete(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('push_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: :delete,
            method: (external_system.config.dig('push_config', __method__.to_s, 'method') || external_system.config.dig('push_config', 'method') || :delete).to_sym,
            transformation: external_system.config.dig('push_config', __method__.to_s, 'transformation') || external_system.config.dig('push_config', 'transformation') || :json_partial,
            path: format(external_system.config.dig('push_config', __method__.to_s, 'path') || external_system.config.dig('push_config', 'path') || '/delete', id: data&.id),
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
