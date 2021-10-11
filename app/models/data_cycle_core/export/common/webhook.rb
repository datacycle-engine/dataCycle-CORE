# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      class Webhook
        def initialize(data:, method:, body:, endpoint:)
          @data = data
          @method = method
          @body = body
          @endpoint = endpoint
        end

        def perform
          raise NotImplementedError
        end

        def queue_name
          'webhooks'
        end

        def reference_type
          raise NotImplementedError
        end

        def max_attempts
          10
        end

        def enqueue(job)
          job.delayed_reference_id = @data.id
          job.delayed_reference_type = reference_type
        end

        def before(job)
          previous_job = Delayed::Job.where(queue: queue_name, delayed_reference_id: @data.id, delayed_reference_type: reference_type).order(created_at: :desc).find_by('created_at < ?', job.created_at)

          return if previous_job.nil?

          begin
            previous_job.invoke_job
            previous_job.destroy!
          rescue StandardError
            raise DataCycleCore::Export::Common::Error::WebhookError, "Delayed job sequential error for: #{job.id} (parent: #{previous_job.id})"
          end
        end
      end
    end
  end
end
