# frozen_string_literal: true

module DataCycleCore
  class WebhookJob < UniqueApplicationJob
    queue_as :webhooks
    queue_with_priority 5

    ATTEMPTS = 10
    WAIT = :exponentially_longer

    attr_accessor :data, :utility_object, :external_sync, :response, :start_time

    before_perform :initialize_context
    before_perform :check_filter
    before_perform :init_external_sync
    after_success :success_external_sync
    after_error :error_external_sync
    after_failure :failure_external_sync

    def delayed_reference_id
      arguments.dig(0, :data_object, :id)
    end

    def discard_on_failure?
      utility_object&.discard_job_on_failure?
    end

    def delayed_reference_type
      [
        arguments.dig(0, :external_system_id),
        arguments.dig(0, :action)&.to_s
      ].compact_blank.join('_')
    end

    def perform(*)
      @response = utility_object.send_request(data)
    end

    def init_external_sync
      @external_sync = data.external_system_sync_by_system(external_system: utility_object.external_system) if data.respond_to?(:external_system_sync_by_system)

      @start_time = Time.zone.now
      external_sync&.update(status: 'pending', last_sync_at: start_time)
      instrument_status(:info, '[STARTED]')
    end

    def success_external_sync
      external_sync&.update(status: 'success', last_successful_sync_at: start_time, data: external_sync&.data&.except('exception'))
      instrument_status(:info, "[FINISHED] in #{(Time.zone.now - start_time).round(3)}s")
    end

    def error_external_sync
      external_sync&.update(status: 'error', exception_data:)
      instrument_status(:warn, "[ERROR] | #{exception_message}")
    end

    def failure_external_sync
      external_sync&.update(status: 'failure', exception_data:)
      instrument_status(:error, "[FAILURE] | #{exception_message}")
    end

    def initialize_context
      throw :abort if arguments.blank?

      @data = parse_data_item(arguments.dig(0, :data_object))
      @utility_object = DataCycleCore::Export::PushObject.new(
        **arguments[0].except(:data_object)
      )
    rescue ActiveModel::MissingAttributeError
      throw :abort
    end

    # check filters for the webhook
    def check_filter
      throw :abort unless utility_object.filter_checked? || utility_object.allowed?(data)
    end

    private

    def instrument_status(severity, message_details)
      return if utility_object.blank? || utility_object.external_system.blank?

      message = [
        '[E]',
        utility_object.external_system.name,
        utility_object.action,
        "[#{utility_object.endpoint_method}][#{executions}][#{data.try(:id)}]",
        '...',
        message_details
      ].join(' ')

      ActiveSupport::Notifications.instrument 'export_job_status.datacycle', {
        job: self,
        severity:,
        message:
      }
    end

    def exception_data
      return if last_error.blank?

      text = last_error.try(:response)&.dig(:body)&.to_s&.dup&.encode_utf8! if last_error.try(:response).respond_to?(:dig)

      {
        timestamp: Time.zone.now,
        message: last_error.message.dup.encode_utf8!,
        text:
      }
    end

    def exception_message
      return if last_error.blank?

      message = [last_error.message.dup.encode_utf8!]
      message << "#{last_error.backtrace.first(10).join("\n")}\n" if last_error.backtrace.present?

      message.join("\n\n")
    end

    def parse_data_item(data)
      item = data[:klass]&.safe_constantize&.find_by(id: data[:id]) ||
             OpenStruct.new(data) # rubocop:disable Style/OpenStructUse

      if data[:webhook_data].present? && item.respond_to?(:webhook_data)
        item.webhook_data = OpenStruct.new(data[:webhook_data]) # rubocop:disable Style/OpenStructUse
      end

      item.original_id = data[:original_id] if data[:original_id].present? && item.respond_to?(:original_id)

      return item unless item.class.const_defined?(:WEBHOOK_ACCESSORS)

      item.class::WEBHOOK_ACCESSORS.each do |accessor|
        item.send(:"#{accessor}=", data[accessor.to_sym])
      end

      item
    end
  end
end
