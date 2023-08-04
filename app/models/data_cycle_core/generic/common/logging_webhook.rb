# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      class LoggingWebhook < DataCycleCore::Generic::WebhookBase
        INTERNAL_KEYS = ['controller', 'action', 'format', 'external_source_id'].freeze

        def update(data, external_system)
          perform(data, external_system)
        end

        def create(data, external_system)
          perform(data, external_system)
        end

        def delete(data, external_system)
          perform(data, external_system)
        end

        def perform(data, _external_system)
          Activity.create!(activity_type: 'webhook', data:)

          data.except(*INTERNAL_KEYS)
        end
      end
    end
  end
end
