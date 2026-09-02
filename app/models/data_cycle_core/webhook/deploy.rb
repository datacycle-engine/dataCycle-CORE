# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Deploy < Base
      def self.execute_all(data, external_system_id: nil)
        Base.execute_all(data, 'deploy', external_system_id:)
      end

      def self.deployable?(data)
        deploy_hooks = webhooks_for('deploy', data)
        deploy_hooks.present? &&
          deploy_hooks.any? { |hook| hook.allowed?(data) }
      end
    end
  end
end
