module DataCycleCore
  module Webhook
    class Base

      def self.log(webhook, message)
        # logger = Logger.new('webhook')
        Rails.logger.info("#{webhook}: #{message}")
      end

      def self.get_webhooks_for(action)
        DataCycleCore.webhooks.try(:[], action.try(:to_sym)).nil? == false ? DataCycleCore.webhooks.try(:[], action.try(:to_sym)) : []
      end

    end
  end
end
