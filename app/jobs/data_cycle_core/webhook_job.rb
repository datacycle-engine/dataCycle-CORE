# frozen_string_literal: true

module DataCycleCore
  class WebhookJob < ApplicationJob
    queue_as :webhooks
    queue_with_priority 5

    attr_accessor :data, :utility_object, :external_sync, :response

    before_enqueue ->(job) { initialize_context(job) }
    before_perform ->(job) { initialize_context(job) }

    retry_on StandardError, attempts: 10, wait: :exponentially_longer do |job, exception|
      job.failure(exception)
    end

    def failure(exception)
      external_sync&.update(
        status: 'failure',
        data: {
          message: exception.message.dup.encode_utf8!,
          text: exception.try(:response)&.dig(:body)&.dup&.encode_utf8!
        }
      )
    end

    # doesn't work with delayed_job backend
    # rescue_from StandardError do |exception|
    #   job.external_sync&.update(
    #     status: 'error',
    #     data: {
    #       message: exception.message.dup.encode_utf8!,
    #       text: exception.try(:response)&.dig(:body)&.dup&.encode_utf8!
    #     }
    #   )

    #   raise exception
    # end

    def delayed_reference_id
      data.id
    end

    def delayed_reference_type
      utility_object.reference_type
    end

    around_enqueue do |job, block|
      # remove all previous jobs, that haven't failed yet
      self.class.by_identifiers(
        reference_id: job.delayed_reference_id,
        reference_type: job.delayed_reference_type,
        queue_name: job.queue_name
      ).each(&:destroy)

      block.call
    end

    around_perform do |job, block|
      # check filter for webhook if it was not checked before
      return unless job.utility_object.filter_checked? || job.utility_object.allowed?(data)

      job.external_sync = job.data.external_system_sync_by_system(external_system: job.utility_object.external_system) if job.data.is_a?(DataCycleCore::Thing)

      job.external_sync&.update(status: 'pending', last_sync_at: Time.zone.now)

      I18n.with_locale(job.utility_object.locale) do
        block.call
      end

      job.external_sync&.update(status: 'success', last_successful_sync_at: job.external_sync.last_sync_at)
    end

    def perform(*)
      @response = utility_object.send_request(data)
    end

    private

    def initialize_context(job)
      return if job.arguments.blank?

      data, action, external_system_id, locale, filter_checked, type, path, endpoint_method = job.arguments

      @data = parse_data_item(data)
      @utility_object = DataCycleCore::Export::PushObject.new(
        action:,
        external_system: DataCycleCore::ExternalSystem.find(external_system_id),
        locale:,
        filter_checked:,
        type:,
        path:,
        endpoint_method:
      )
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
        item.send("#{accessor}=", data[accessor.to_sym])
      end

      item
    end
  end
end
