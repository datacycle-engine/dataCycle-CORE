# frozen_string_literal: true

module DataCycleCore
  module Jobs
    CacheInvalidationDestroyJob = Struct.new(:class_name, :id, :method_name, :things_ids) do
      def perform
        send(method_name)
      end

      def queue_name
        'cache_invalidation'
      end

      def enqueue(job)
        job.priority = 10
        job.delayed_reference_id = id
        job.delayed_reference_type = "#{class_name.underscore}_#{method_name}"
      end

      def execute_things_webhooks_destroy
        return if things_ids.blank?

        DataCycleCore::Thing.where(id: things_ids).find_each do |content|
          content.send(:execute_update_webhooks)
        end
      end

      def invalidate_things_cache
        return if things_ids.blank?

        things_ids.each do |thing_id|
          Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new('DataCycleCore::Thing', thing_id, :invalidate_self_and_update_search) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: 'data_cycle_core/thing_invalidate_self_and_update_search', delayed_reference_id: thing_id, locked_at: nil)
        end
      end
    end
  end
end
