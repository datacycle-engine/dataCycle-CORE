# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Create < Base
      def self.execute_all(data)
        get_webhooks_for('create', data).each do |external_system, webhook|
          webhook.process(utility_object: DataCycleCore::Export::PushObject.new(external_system: external_system), data: data)
        end
      end
    end
  end
end
