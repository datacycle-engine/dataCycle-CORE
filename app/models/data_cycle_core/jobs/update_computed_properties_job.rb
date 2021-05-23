# frozen_string_literal: true

module DataCycleCore
  module Jobs
    UpdateComputedPropertiesJob = Struct.new(:content_class, :content_id) do
      QUEUE_NAME = 'cache_invalidation'

      PRIORITY = 12

      def perform
        query = ActiveRecord::Base.send(:sanitize_sql_array, [
            'SELECT DISTINCT content_id FROM content_property_dependencies WHERE dependent_content_id = ?',
            content_id
          ])

        dependent_content_ids = ActiveRecord::Base.connection.execute(query).values

        DataCycleCore::Thing.where(id: dependent_content_ids).each do |item|
          if (item.computed_property_names & item.translatable_property_names).present?
            item.available_locales.each do |locale|
              I18n.with_locale(locale) do
                item.set_data_hash(data_hash: item.get_data_hash.except(*item.computed_property_names))
              end
            end
          else
            I18n.with_locale(item.first_available_locale) do
              item.set_data_hash(data_hash: item.get_data_hash.except(*item.computed_property_names))
            end
          end
        end
      end

      def queue_name
        QUEUE_NAME
      end

      def enqueue(job)
        job.priority = PRIORITY
        job.delayed_reference_id = content_id
        job.delayed_reference_type = content_class
      end
    end
  end
end
