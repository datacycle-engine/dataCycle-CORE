# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module FunctionsExtensions
        def enqueue(utility_object:, data:)
          external_system = utility_object.external_system
          data_object = { id: data.id, klass: data.class.name }
          append_thing_data!(data_object, data, external_system)

          queue_method = synchronous_webhooks?(data, utility_object) ? :perform_now : :perform_later
          webhook = utility_object.webhook_job_class.set(**enqueue_options(data, utility_object))

          webhook.send(
            queue_method,
            data_object:,
            action: utility_object.action,
            external_system_id: external_system.id,
            locale: I18n.locale,
            filter_checked: utility_object.filter_checked?,
            type: utility_object.type,
            path: utility_object.path,
            endpoint_method: utility_object.endpoint_method,
            transformation: utility_object.transformation
          )
        end

        def synchronous_webhooks?(data, utility_object)
          data.try(:synchronous_webhooks) ||
            (
              utility_object.external_system.export_config.dig(utility_object.action, :queue) ||
              utility_object.external_system.export_config[:queue]
            ) == 'inline' # legacy config support
        end

        # Every option the enqueue steers has to reach the one .set call above: ActiveJob::ConfiguredJob,
        # which .set returns, carries no #set of its own, so a second one chained onto it would raise
        # NoMethodError. A blank option is dropped rather than passed as nil - given a wait_until of
        # Time.zone.now, ActiveJob stamps scheduled_at and SolidQueue files the delivery under
        # solid_queue_scheduled_executions for its scheduler to promote, where one with no scheduled_at
        # is claimed ready.
        # @return [Hash] the ActiveJob options, empty when nothing steers this enqueue
        def enqueue_options(data, utility_object)
          {
            wait_until: data.try(:webhook_run_at),
            wait: utility_object.wait_time,
            priority: data.try(:webhook_priority)
          }.compact_blank
        end

        def append_thing_data!(data_object, data, external_system)
          data_object[:template_name] = data.template_name if data.respond_to?(:template_name)
          if data.is_a?(DataCycleCore::Thing)
            data_object[:webhook_data] = data.webhook_data.to_h.merge(
              external_keys: data.external_keys_by_system_id(external_system.id),
              original_external_keys: data.try(:original)&.external_keys_by_system_id(external_system.id)
            )
          end

          data_object[:original_id] = data.original_id if data.respond_to?(:original_id)
          data_object[:duplicate_id] = data.duplicate_id if data.respond_to?(:duplicate_id)

          if data.respond_to?(:additional_webhook_attributes)
            data.additional_webhook_attributes.each do |key|
              data_object[key.to_sym] = data.send(key) if data.respond_to?(key)
            end
          end

          return unless data.class.const_defined?(:WEBHOOK_ACCESSORS)

          data.class::WEBHOOK_ACCESSORS.each do |accessor|
            data_object[accessor.to_sym] = data.send(accessor)
          end
        end
      end
    end
  end
end
