module DataCycleCore
  module Webhook
    class Base
      def self.log(webhook, message)
        # logger = Logger.new('webhook')
        Rails.logger.info("#{webhook}: #{message}")
      end

      def self.get_webhooks_for(action, data)
        webhooks = DataCycleCore.webhooks.try(:[], action.try(:to_sym))

        webhooks.blank? ? [] : webhooks.collect { |webhook| validate_webhook(webhook, data) }.reject(&:blank?)
      end

      def self.validate_webhook(webhook, data)
        return webhook if webhook.is_a?(Class)

        if webhook.is_a?(Hash)
          webhook_class = webhook.keys.first
          filter = webhook[webhook_class].fetch(:filter) { raise KeyError, "Filter must be supplied for webhook" }

          return webhook_class if filter.call(data)
        end
      end
    end
  end
end
