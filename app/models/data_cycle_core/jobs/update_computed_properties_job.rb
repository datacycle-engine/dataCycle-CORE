# frozen_string_literal: true

module DataCycleCore
  module Jobs
    UpdateComputedPropertiesJob = Struct.new(:content_id) do
      def perform
        # SELECT DISTINCT content_id
        # FROM content_property_dependencies
        # WHERE dependent_content_id = '36e86de6-8104-4584-bd72-3ae6fa6dccb5';

        # items.each do |item|
        #   item.available_locales.each do |locale|
        #     I18n.with_locale(locale) do
        #       item.set_data_hash(data_hash: item.get_data_hash.except(*template.computed_property_names)) }
        #     end
        #   end
        # end
      end

      def queue_name
        'cache_invalidation'
      end

      def enqueue(job)
        job.priority = 12
      end
    end
  end
end
