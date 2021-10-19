# frozen_string_literal: true

module DataCycleCore
  class WebhooksJob < UniqueApplicationJob
    PRIORITY = 4

    queue_as :webhooks

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      unique_attribute_string = arguments[3]
        &.slice(*arguments[1].safe_constantize::WEBHOOK_ACCESSORS)
        &.map { |k, v| "#{k}_#{v}" }
        &.join('_')

      "check_for_#{arguments[2]}_webhooks_#{unique_attribute_string}"
    end

    def perform(id, class_name, job_type, additional_attributes = {})
      content = class_name.safe_constantize.find_by(id: id)

      return if content.nil?

      additional_attributes&.slice(*content.class::WEBHOOK_ACCESSORS)&.each do |key, value|
        content.send("#{key}=", value)
      end

      content.webhook_data = OpenStruct.new(additional_attributes[:webhook_data]) if additional_attributes[:webhook_data].present?

      "DataCycleCore::Webhook::#{job_type.classify}".safe_constantize.execute_all(content)
    end
  end
end
