# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      class Webhook
        # TODO: move error to core
        class WebhookSequentialError < StandardError
          def initialize(msg = '')
            super
          end
        end

        def initialize(data:, method:, body:, endpoint:)
          @data = data
          @method = method
          @body = body
          @endpoint = endpoint
        end

        # TODO: Move logger to Core
        def logger
          # Rails.logger
          Logger.new('./log/webhook.log')
        end

        def perform
          @endpoint.log_request(
            data: @data,
            body: @body
          )
        end

        def queue_name
          "text_file_creative_work_#{@data.id}"
        end

        def max_attempts
          10
        end

        def enqueue(job)
          job.delayed_reference_id = @data.id
          job.delayed_reference_type = @data.template_name
        end

        def before(job)
          first_available_job = Delayed::Job.where(queue: queue_name).find_by('created_at < ?', job.created_at)

          raise WebhookSequentialError, "Delayed job sequential error for: #{job.id} (parent: #{first_available_job.id})" unless first_available_job.nil?
        end
      end
    end
  end
end
