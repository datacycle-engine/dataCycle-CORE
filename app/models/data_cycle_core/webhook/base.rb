# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Base
      def self.execute_all(data, action)
        return if data.try(:prevent_webhooks) == true

        webhooks_for(action, data).each do |utility_object|
          execute(utility_object, data)
        rescue SystemStackError => e
          ActiveSupport::Notifications.instrument 'webhooks_failed.datacycle', {
            exception: e,
            action:,
            payload: data
          }
        end
      end

      def self.execute(utility_object, data)
        # check filter for webhook immediately if it is delete action
        return if utility_object.delete_action? && !utility_object.allowed?(data)

        utility_object.process(data)
      end

      def self.available_system_names(data)
        allowed_webhooks = Array.wrap(DataCycleCore.webhooks) - Array.wrap(data.try(:webhook_source)) - Array.wrap(data.try(:prevent_webhooks))
        allowed_webhooks = allowed_webhooks.intersection(Array.wrap(data.try(:allowed_webhooks))) if data.try(:allowed_webhooks).present?

        allowed_webhooks
      end

      def self.webhooks_for(action, data)
        DataCycleCore::ExternalSystem
          .where(name: available_system_names(data))
          .filter_map do |external_system|
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
