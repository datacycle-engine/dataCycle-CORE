# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TileBorderColor < Base
      class << self
        def class_string(content)
          return unless enabled? &&
                        content.is_a?(DataCycleCore::Thing) &&
                        filter_by_template_names(content)

          class_list = []
          class_list.concat(Array.wrap(tree_label_classes(content)))
          class_list.concat(Array.wrap(event_schedule_classes(content)))
          class_list.concat.join(' ')
        end

        private

        def filter_by_template_names(content)
          configuration[:template_name].blank? || content&.template_name&.in?(Array.wrap(configuration[:template_name]))
        end

        def tree_label_classes(content)
          return if configuration[:tree_label].blank?

          content&.classification_aliases&.for_tree(configuration[:tree_label])&.map { |c| "#{c.classification_tree_label&.name}_#{c.internal_name}".underscore_blanks }
        end

        def event_schedule_classes(content)
          return if configuration[:event_schedule].blank? || !content.respond_to?(:event_schedule)

          return ['event_schedule_past'] if content.event_schedule.presence&.none? { |es| es.schedule_object.next_occurrence(Time.zone.now, spans: true).present? }
        end
      end
    end
  end
end
