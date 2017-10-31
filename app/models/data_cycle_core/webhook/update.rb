module DataCycleCore
  module Webhook
    class Update < Base

      def self.execute_all(data)
        log self.name, "#{data.id} (#{data.metadata['validation']['name']})"

        get_webhooks_for('update').each do |webhook|
          webhook.new.execute(data)
        end

      end

    end
  end
end