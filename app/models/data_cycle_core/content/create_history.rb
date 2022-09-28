# frozen_string_literal: true

module DataCycleCore
  module Content
    module CreateHistory
      THING_HISTORY_ATTRIBUTE_EXCEPTIONS = [
        'id',
        'created_at',
        'updated_at',
        'write_history'
      ].freeze
      CLASSIFICATION_CONTENT_HISTORY_ATTRIBUTE_EXCEPTIONS = [
        'id',
        'content_data_id',
        'content_data_type'
      ].freeze
      SCHEDULE_HISTORY_ATTRIBUTE_EXCEPTIONS = [
        'id',
        'thing_id'
      ].freeze

      def to_history(delete: false, all_translations: false)
        origin_table = self.class.to_s.split('::')[1].tableize
        data_set_history = (self.class.to_s + '::History').safe_constantize.new

        # cc self to history
        data_set_history.send(origin_table.singularize.foreign_key + '=', id)

        I18n.with_locale(last_updated_locale) do
          if all_translations
            available_locales.except(last_updated_locale&.to_sym).each do |locale|
              I18n.with_locale(locale) do
                attributes.except(*THING_HISTORY_ATTRIBUTE_EXCEPTIONS).each do |key, value|
                  data_set_history.send("#{key}=", value)
                end

                lower_bound = update_previous_history_validity
                data_set_history.history_valid = (lower_bound...)
              end
            end
          end

          attributes.except(*THING_HISTORY_ATTRIBUTE_EXCEPTIONS).each do |key, value|
            data_set_history.send("#{key}=", value)
          end

          lower_bound = update_previous_history_validity
          data_set_history.history_valid = (lower_bound...)
          data_set_history.deleted_at = lower_bound if delete
          data_set_history.created_at = lower_bound
          data_set_history.updated_at = lower_bound
          data_set_history.save(touch: false)

          data_set_history.classification_content_history.insert_all(classification_content.map { |cc| cc.attributes.except(*CLASSIFICATION_CONTENT_HISTORY_ATTRIBUTE_EXCEPTIONS) }) if classification_content.any?

          embedded_property_names.each do |content_name|
            load_embedded_objects(content_name, nil, !all_translations).each_with_index do |content_item, index|
              new_content_history = content_item.to_history
              DataCycleCore::ContentContent::History.create!({
                content_a_history_id: data_set_history.id,
                relation_a: content_name,
                order_a: index,
                content_b_history_id: new_content_history.id,
                content_b_history_type: 'DataCycleCore::Thing::History',
                history_valid: ((lower_bound || content_item.created_at)...)
              })
            end
          end

          linked_property_names.each do |content_name|
            properties = properties_for(content_name)
            next if properties.dig('link_direction') == 'inverse'

            next unless load_linked_objects(content_name).any?

            data_set_history.content_content_a_history.insert_all(
              load_linked_objects(content_name).map.with_index do |content_item, index|
                {
                  relation_a: content_name,
                  order_a: index,
                  relation_b: properties.dig('inverse_of'),
                  content_b_history_id: content_item.id,
                  content_b_history_type: 'DataCycleCore::Thing',
                  history_valid: ((lower_bound || content_item.created_at)...)
                }
              end
            )
          end

          schedule_property_names.each do |content_name|
            schedules = load_schedule(content_name)
            next if schedules.blank?
            schedules.each do |schedule_data|
              schedule_history = DataCycleCore::Schedule::History.new
              schedule_data.attributes.except(*SCHEDULE_HISTORY_ATTRIBUTE_EXCEPTIONS).each do |key, value|
                schedule_history.send("#{key}=", value)
              end
              schedule_history.thing_history_id = data_set_history.id
              schedule_history.save
            end
          end
        end

        data_set_history
      end

      def update_previous_history_validity
        previous_history = histories.includes(:translations).where(thing_history_translations: { locale: I18n.locale }).find_by('UPPER(thing_history_translations.history_valid) IS NULL')

        return updated_at if previous_history.nil?

        start_time = [previous_history.history_valid&.first, previous_history.created_at].compact.max
        end_time = updated_at
        end_time = start_time + 0.000001 if start_time >= end_time # ensure history_valid is a valid range

        previous_history.history_valid = (start_time...end_time)
        previous_history.save(touch: false)

        DataCycleCore::ContentContent::History.where(content_a_history_id: previous_history.id).update_all(["history_valid = tstzrange(lower(content_content_histories.history_valid), ?, '[)')", end_time])

        end_time
      end
    end
  end
end
