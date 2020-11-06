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
          template_names = Array.wrap(external_system.config.dig('export_config', method_name, 'filter', 'template_names') || external_system.config.dig('export_config', 'filter', 'template_names'))
          external_system_names = Array.wrap(external_system.config.dig('export_config', method_name, 'filter', 'external_systems') || external_system.config.dig('export_config', 'filter', 'external_systems'))
          classification_ids = Array.wrap(external_system.config.dig('export_config', method_name, 'filter', 'classifications') || external_system.config.dig('export_config', 'filter', 'classifications')).map { |f| DataCycleCore::ClassificationAlias.classification_for_tree_with_name(f['tree_label'], f['aliases']) }

          (template_names.present? ? data.template_name.in?(template_names) : true) && (classification_ids.present? ? classification_ids.all? { |c| data.classifications.map(&:id).include?(c) } : true) && (external_system_names.present? ? data.external_source&.identifier&.in?(external_system_names) : true)
        end

        def self.enqueue_webhook(data, webhook, external_system)
          data.add_external_system_data(external_system, nil, 'pending')
          delayed_job = Delayed::Job.where(queue: 'webhooks', delayed_reference_type: webhook.reference_type, delayed_reference_id: data.id, locked_at: nil).order(created_at: :asc).first
          run_at = data.webhook_run_at || Time.zone.now
          priority = data.webhook_priority || Delayed::Worker.default_priority

          if delayed_job.nil? || data.webhook_as_of.present?
            Delayed::Job.enqueue(webhook, run_at: run_at, created_at: run_at, updated_at: run_at, priority: priority)
          else
            delayed_job.update(run_at: [delayed_job.run_at, run_at].min, created_at: [delayed_job.created_at, run_at].min, updated_at: [delayed_job.updated_at, run_at].min, priority: [delayed_job.priority, priority].min)
          end
        end

        def self.create(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: 'create',
            method: (external_system.config.dig('export_config', __method__.to_s, 'method') || external_system.config.dig('export_config', 'method') || :post).to_sym,
            transformation: external_system.config.dig('export_config', __method__.to_s, 'transformation') || external_system.config.dig('export_config', 'transformation') || :json_partial,
            path: utility_object.endpoint.path_transformation(data, external_system, 'create'),
            utility_object: utility_object,
            locale: I18n.locale
          )

          enqueue_webhook(data, webhook, external_system)
        end

        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: 'update',
            method: (external_system.config.dig('export_config', __method__.to_s, 'method') || external_system.config.dig('export_config', 'method') || :put).to_sym,
            transformation: external_system.config.dig('export_config', __method__.to_s, 'transformation') || external_system.config.dig('export_config', 'transformation') || :json_partial,
            path: utility_object.endpoint.path_transformation(data, external_system, 'update'),
            utility_object: utility_object,
            locale: I18n.locale
          )

          enqueue_webhook(data, webhook, external_system)
        end

        def self.delete(utility_object:, data:)
          external_system = utility_object.external_system
          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name),
            type: 'delete',
            method: (external_system.config.dig('export_config', __method__.to_s, 'method') || external_system.config.dig('export_config', 'method') || :delete).to_sym,
            transformation: external_system.config.dig('export_config', __method__.to_s, 'transformation') || external_system.config.dig('export_config', 'transformation') || :json_partial,
            path: utility_object.endpoint.path_transformation(data, external_system, 'delete'),
            utility_object: utility_object,
            locale: I18n.locale
          )

          enqueue_webhook(data, webhook, external_system)
        end
      end
    end
  end
end
