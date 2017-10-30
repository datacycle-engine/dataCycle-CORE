module DataCycleCore
  module Webhook
    class Create < Base

      def self.execute_all(data)
        log self.name, data.id

        get_webhooks_for('update').each do |webhook|
          webhook.execute(data)
        end

      end

    end
  end
end