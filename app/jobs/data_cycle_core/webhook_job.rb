# frozen_string_literal: true

module DataCycleCore
  class WebhookJob < UniqueApplicationJob
    queue_as :webhooks
    queue_with_priority 5
    # Two enqueues are duplicates only when they would send the same content to the same place, so
    # every argument that steers the request joins the key. :type and :path are what
    # DataCycleCore::Export::PushObject#transformed_path builds the URL from, and :endpoint_method
    # names the method called on the endpoint - a status poll and the push it follows up on share
    # content, system and action, and differ in nothing else. A media archive update likewise enqueues
    # /api/v1/photographers and /api/v1/licenses for one content, system and :update action: on a
    # content/system/action key those two deliveries are indistinguishable.
    CONCURRENCY_KEY_ARGUMENTS = [[:data_object, :id], [:external_system_id], [:action], [:endpoint_method], [:type], [:path]].freeze

    limits_concurrency key: ->(*args) { CONCURRENCY_KEY_ARGUMENTS.filter_map { |keys| args.dig(0, *keys) }.join('/') }

    ABORT_ON_NIL_ACTIONS = [:create, :update].freeze

    attr_accessor :data, :utility_object, :external_sync, :response, :start_time

    before_perform :initialize_context
    before_perform :check_filter
    before_perform :init_external_sync
    after_success :success_delete
    after_success :success_external_sync
    after_error :error_external_sync
    after_failure :failure_external_sync

    def discard_on_failure?
      utility_object&.discard_job_on_failure?
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

    def success_delete
      return unless utility_object.action.to_s == 'delete'

      if utility_object.external_system.remove_external_system_syncs_on_delete? && data.respond_to?(:external_system_syncs) && !delete_response_failed?
        DataCycleCore::Export::SyncCleanup.new(content: data, external_system: utility_object.external_system).call
      else
        external_sync&.update(sync_type: 'duplicate')
      end
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

    # #initialize_context re-read the content, so the filter runs again on what it has become since the
    # save - a content that left the export's scope in between is dropped here rather than pushed.
    # filter_checked? is a verdict this job may not retake;
    # DataCycleCore::Export::PushObject::FINAL_VERDICT_ACTIONS says which those are.
    def check_filter
      throw :abort unless utility_object.filter_checked? || utility_object.allowed?(data)
    end

    private

    # only skip sync cleanup on an explicit failure response (e.g. DZT returns
    # { 'job_status' => 'failed' }); keeps cleanup correct regardless of the
    # order in which after_success callbacks run
    def delete_response_failed?
      response.is_a?(Hash) && response['job_status'].to_s == 'failed'
    end

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

    # Faraday::Error#response is a Hash; our own EndpointError classes wrap a Faraday::Response object
    def response_status(response)
      return response[:status] if response.is_a?(Hash)

      response.try(:status)
    end

    def response_body(response)
      body = response.is_a?(Hash) ? response[:body] : response.try(:body)
      body&.to_s&.dup&.encode_utf8!
    end

    def exception_data
      return if last_error.blank?

      response = (last_error.try(:original_error) || last_error).try(:response)

      {
        timestamp: Time.zone.now,
        status: response_status(response),
        message: last_error.message.dup.encode_utf8!,
        text: response_body(response)
      }
    end

    def exception_message
      return if last_error.blank?

      message = [last_error.message.dup.encode_utf8!]
      message << "#{last_error.backtrace.first(10).join("\n")}\n" if last_error.backtrace.present?

      message.join("\n\n")
    end

    def parse_data_item(data)
      item = data[:klass]&.safe_constantize&.find_by(id: data[:id])

      if item.nil?
        throw :abort if ABORT_ON_NIL_ACTIONS.include?(arguments.dig(0, :action))
        item = OpenStruct.new(data) # rubocop:disable Style/OpenStructUse
      end

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
