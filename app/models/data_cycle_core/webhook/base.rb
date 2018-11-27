# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Base
      def self.log(webhook, message)
        # logger = Logger.new('webhook')
        Rails.logger.info("#{webhook}: #{message}")
      end

      def self.get_webhooks_for(action, data)
        external_systems = DataCycleCore.webhooks.collect { |hook| DataCycleCore::ExternalSystem.find_by(name: hook) }.compact

        webhooks = external_systems.collect { |external_system| external_system.push_config.dig(action.to_sym) }.compact
        webhooks.blank? ? [] : webhooks.collect { |webhook| validate_webhook(webhook.symbolize_keys, data) }.reject(&:blank?)
      end

      def self.validate_webhook(webhook, data)
        return unless webhook.dig(:strategy) || !webhook.dig(:strategy).is_a?(Class)

        export_class = webhook.dig(:strategy).constantize
        return export_class if export_class.filter(data)
        nil
      end
    end
  end
end
