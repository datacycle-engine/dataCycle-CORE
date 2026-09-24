# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Base
      def self.execute_all(data, action, external_system_id: nil)
        return if data.try(:prevent_webhooks) == true

        webhooks_for(action, data, external_system_id:).each do |utility_object|
          execute(utility_object, data)
        rescue SystemStackError => e
          ActiveSupport::Notifications.instrument 'webhooks_failed.datacycle', {
            exception: e,
            action:,
            payload: data
          }
        end
      end

      # Before the enqueue rather than only in DataCycleCore::WebhookJob#check_filter: a content the
      # filter rejects otherwise costs a solid_queue_jobs row, a concurrency semaphore and a worker
      # claim to reach the same answer. It does not replace that check for a create or an update -
      # DataCycleCore::Export::PushObject#allowed? says which verdicts travel with the job and why.
      #
      # Unconditional on purpose: #allowed? runs the receiver's export strategy, which may gate on
      # more than the configured filter. A caller that has answered part of that filter for a whole
      # set says so on the content, and DataCycleCore::Export::Generic::Filter.filter_endpoints is
      # where that mark is honoured - see its doc block for why it belongs there and not here.
      def self.execute(utility_object, data)
        return unless utility_object.allowed?(data)

        utility_object.process(data)
      end

      def self.available_system_names(data)
        allowed_webhooks = Array.wrap(DataCycleCore.webhooks) - Array.wrap(data.try(:webhook_source)) - Array.wrap(data.try(:prevent_webhooks))
        allowed_webhooks = allowed_webhooks.intersection(Array.wrap(data.try(:allowed_webhooks))) if data.try(:allowed_webhooks).present?

        allowed_webhooks
      end

      def self.webhooks_for(action, data, external_system_id: nil)
        scope = DataCycleCore::ExternalSystem.where(name: available_system_names(data))
        scope = scope.where(id: external_system_id) if external_system_id.present?

        scope.filter_map do |external_system|
          utility_object_for(external_system, action, data)
        end
      end

      def self.utility_object_for(external_system, action, data)
        utility_object = DataCycleCore::Export::PushObject.new(
          external_system:,
          action:
        )

        return unless utility_object.webhook_valid?(data)

        utility_object
      end
    end
  end
end
