module DataCycleCore
  module Webhook
    class Delete < Base

      def self.execute_all(data)
        log self.name, "#{data.id} (#{data.metadata['validation']['name']})"

        get_webhooks_for('delete').each do |webhook|
          webhook.new.execute(data)
        end

      end

    end
  end
end