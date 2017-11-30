module DataCycleCore
  module Webhook
    class Update < Base

      def self.execute_all(data)
        log self.name, "#{data.id} (#{data.metadata['validation']['name']})"

        get_webhooks_for('update').each do |webhook|
          if webhook.kind_of?(Hash)
            options = webhook.try(:[], webhook.keys.first)
            filter = options.try(:[], :filter)
            #validate filter

            webhook = webhook.keys.first
          end
          webhook.new.execute(data)
        end

      end

    end
  end
end