# frozen_string_literal: true

module DataCycleCore
  module Content
    module Restorable
      def restore
        self.class.transaction(joinable: false, requires_new: true) do
          update_columns(deleted_at: nil, deleted_by: nil)

          content = restore_content
          restore_classification_contents
          restore_content_contents
          restore_schedules

          content.search_languages(true)
        end
      end

      private

      def restore_content
        content = DataCycleCore::Thing.create!(attributes.slice(*DataCycleCore::Thing.column_names).merge(
                                                 'id' => thing_id,
                                                 'version_name' => I18n.t('history.restored', date: I18n.l(Time.zone.now, format: :edit)),
                                                 'created_at' => DataCycleCore::Thing::History.order(created_at: :asc).find_by(thing_id:)&.created_at
                                               ))

        translations.each do |translated_entry|
          DataCycleCore::Thing::Translation.create!(translated_entry.attributes.slice(*DataCycleCore::Thing::Translation.column_names.except('id')).merge('thing_id' => thing_id))
        end

        content
      end

      def restore_classification_contents
        classification_content_history.where.not(classification_id: nil).find_each do |clc_history|
          DataCycleCore::ClassificationContent.create!(clc_history.attributes.slice(*DataCycleCore::ClassificationContent.column_names.except('id')).merge('content_data_id' => thing_id))
        rescue ActiveRecord::RecordNotUnique
          nil
        end
      end

      def restore_content_contents
        content_content_a_history.each do |cc_history|
          if cc_history.content_b_history_type == 'DataCycleCore::Thing::History' && cc_history.content_b_history.embedded?
            cc_history.content_b_history.restore
          elsif cc_history.content_b_history_type == 'DataCycleCore::Thing::History' && !cc_history.content_b_history&.thing.nil?
            DataCycleCore::ContentContent.create!(cc_history.attributes.slice(*DataCycleCore::ContentContent.column_names.except('id')).merge('content_a_id' => thing_id, 'content_b_id' => cc_history.content_b_history.thing_id))
          elsif cc_history.content_b_history_type == 'DataCycleCore::Thing'
            DataCycleCore::ContentContent.create!(cc_history.attributes.slice(*DataCycleCore::ContentContent.column_names.except('id')).merge('content_a_id' => thing_id, 'content_b_id' => cc_history.content_b_history_id))
          end
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        content_content_b_history.each do |cc_history|
          next if cc_history.content_a_history&.thing.nil?

          DataCycleCore::ContentContent.create!(cc_history.attributes.slice(*DataCycleCore::ContentContent.column_names.except('id')).merge('content_a_id' => cc_history.content_a_history.thing_id, 'content_b_id' => thing_id))
        rescue ActiveRecord::RecordNotUnique
          nil
        end
      end

      def restore_schedules
        scheduled_history_data.each do |schedule_history|
          DataCycleCore::Schedule.create!(schedule_history.attributes.slice(*DataCycleCore::Schedule.column_names.except('id')).merge('thing_id' => thing_id))
        rescue ActiveRecord::RecordNotUnique
          nil
        end
      end
    end
  end
end
