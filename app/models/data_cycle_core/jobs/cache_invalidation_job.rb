# frozen_string_literal: true

module DataCycleCore
  module Jobs
    CacheInvalidationJob = Struct.new(:class_name, :id, :method_name) do
      def perform
        class_name.classify.constantize.find_by(id: id)&.send(method_name)
      end

      def queue_name
        'cache_invalidation'
      end

      def enqueue(job)
        job.priority = 10
        job.delayed_reference_id = id
        job.delayed_reference_type = class_name
      end
    end
  end
end
