module DataCycleCore
  module Webhook
    class Delete < Base
      def self.execute_all(data)
        log name, "#{data.id} (#{data.metadata['validation']['name']})"

        get_webhooks_for('delete', data).each do |webhook|
          webhook.new.execute(data)
        end
      end
    end
  end
end
