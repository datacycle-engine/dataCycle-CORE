# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Base
      def self.execute_all(data, action)
        get_webhooks_for(action, data).each do |external_system, webhook|
          execute(external_system, webhook, data, action)
        end
      end

      def self.execute(external_system, webhook, data, action)
        utility_object = DataCycleCore::Export::PushObject.new(external_system: external_system)
        init_logging(utility_object) do |logging|
          logging.info("Webhook: #{action} | #{external_system.name} | #{webhook}", data.id)
          webhook.process(utility_object: utility_object, data: data)
        end
      end

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

      def self.init_logging(utility_object)
        logging = utility_object.init_logging(:export)
        yield(logging)
      ensure
        logging.close if logging.respond_to?(:close)
      end
    end
  end
end
