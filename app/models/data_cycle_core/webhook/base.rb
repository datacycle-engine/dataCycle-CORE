# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Base
      def self.get_webhooks_for(action, data)
        DataCycleCore.webhooks
          .collect { |hook| DataCycleCore::ExternalSystem.find_by(name: hook) }
          .collect { |external_system| validate_webhook(external_system, action, data) }.compact
      end

      def self.validate_webhook(external_system, action, data)
        webhook = external_system.push_config.dig(action.to_sym)&.symbolize_keys
        return unless webhook&.dig(:strategy)

        export_class = webhook.dig(:strategy).constantize
        return [external_system, export_class] if export_class.filter(data)
        nil
      end
    end
  end
end
