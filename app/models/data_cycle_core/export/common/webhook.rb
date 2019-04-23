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
          raise NotImplementedError
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

          raise Error::WebhookError, "Delayed job sequential error for: #{job.id} (parent: #{first_available_job.id})" unless first_available_job.nil?
        end
      end
    end
  end
end
