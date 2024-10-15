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

          if previous_job.nil?
            data = @data
            @data = DataCycleCore::Thing.find_by(id: @data.try(:id)) || @data

            return unless @data.is_a?(DataCycleCore::Thing)

            @data.webhook_data = data.webhook_data
            @data.original_id = data.original_id
            @data.external_system_sync_by_system(external_system: @utility_object.external_system).update(last_sync_at: Time.zone.now)

            return
          end

          begin
            previous_job.invoke_job
            previous_job.destroy!
          rescue StandardError
            raise DataCycleCore::Export::Common::Error::SequentialError, "Delayed job sequential error for: #{job.id} (parent: #{previous_job.id})"
          end
        end

        def success(job)
          ActiveSupport::Notifications.instrument 'job_succeeded.datacycle', {
            job_queue: job.queue,
            job_class: job.delayed_reference_type,
            waiting_time: job.created_at ? (Time.zone.now - job.created_at) / 60 : nil,
            attempt_count: job.attempts
          }
        end
      end
    end
  end
end
