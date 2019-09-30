# frozen_string_literal: true

module DataCycleCore
  module Jobs
    SearchUpdateJob = Struct.new(:class_name, :id, :all, :locale) do
      def perform
        class_name.classify.constantize.find_by(id: id)&.update_search_languages(all, locale.to_sym)
      end

      def queue_name
        'search_update'
      end

      def enqueue(job)
        job.priority = 0
        job.delayed_reference_id = "#{id}_#{all ? 'all' : locale}"
        job.delayed_reference_type = class_name
      end
    end
  end
end
