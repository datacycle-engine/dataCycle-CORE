# frozen_string_literal: true

module DataCycleCore
  class WebhooksJob < UniqueApplicationJob
    PRIORITY = 5

    queue_as :webhooks

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      "check_for_#{arguments[2]}_webhooks"
    end

    def perform(id, class_name, job_type)
      content = class_name.safe_constantize.find_by(id: id)

      return if content.nil?

      "DataCycleCore::Webhook::#{job_type.classify}".safe_constantize.execute_all(content)
    end
  end
end
