# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module FunctionsExtensions
        def enqueue(utility_object:, data:)
          external_system = utility_object.external_system
          data_object = { id: data.id, klass: data.class.name }
          append_thing_data!(data_object, data, external_system)

          webhook = utility_object.webhook_job_class
          queue_method = synchronous_webhooks?(data, utility_object) ? :perform_now : :perform_later
          apply_webhook_params!(webhook, data)

          webhook.send(
            queue_method,
            data_object,
            utility_object.action,
            external_system.id,
            I18n.locale,
            utility_object.filter_checked?,
            utility_object.type,
            utility_object.path,
            utility_object.endpoint_method
          )
        end

        def synchronous_webhooks?(data, utility_object)
          data.try(:synchronous_webhooks) ||
            (
              utility_object.external_system.export_config.dig(utility_object.action, :queue) ||
              utility_object.external_system.export_config.dig(:queue)
            ) == 'inline' # legacy config support
        end

        def apply_webhook_params!(webhook, data)
          webhook_params = {
            wait_until: data.try(:webhook_run_at) || Time.zone.now,
            priority: data.try(:webhook_priority)
          }.compact_blank

          webhook.set(**webhook_params) if webhook_params.present?
        end

        def append_thing_data!(data_object, data, external_system)
          data_object[:template_name] = data.template_name if data.respond_to?(:template_name)
          if data.is_a?(DataCycleCore::Thing)
            data_object[:webhook_data] = OpenStruct.new( # rubocop:disable Style/OpenStructUse
              external_keys: data.external_keys_by_system_id(external_system.id),
              original_external_keys: data.try(:original)&.external_keys_by_system_id(external_system.id)
            ).to_h
          end

          data_object[:original_id] = data.original_id if data.respond_to?(:original_id)
          data_object[:duplicate_id] = data.duplicate_id if data.respond_to?(:duplicate_id)

          return unless data.class.const_defined?(:WEBHOOK_ACCESSORS)

          data.class::WEBHOOK_ACCESSORS.each do |accessor|
            data_object[accessor.to_sym] = data.send(accessor)
          end
        end
      end
    end
  end
end
