# frozen_string_literal: true

module DataCycleCore
  module Content
    module CreateHistory
      def to_history(save_time:, delete: false)
        origin_table = self.class.to_s.split('::')[1].tableize
        data_set_history = (self.class.to_s + '::History').safe_constantize.new

        # cc self to history
        data_set_history.send(origin_table.singularize.foreign_key + '=', id)
        attributes.except('id', 'created_at', 'updated_at').each do |key, value|
          data_set_history.send("#{key}=", value)
        end
        lower_bound = updated_at
        lower_bound = save_time if lower_bound > save_time
        data_set_history.history_valid = (lower_bound...save_time)
        data_set_history.deleted_at = save_time if delete
        data_set_history.created_at = save_time
        data_set_history.updated_at = save_time
        data_set_history.save(touch: false)

        # cc classification_content to history
        classification_content.all.find_each do |item|
          classification_history = DataCycleCore::ClassificationContent::History.new
          classification_history.content_data_history_id = data_set_history.id
          item.attributes.except('id', 'content_data_id', 'content_data_type').each do |key, value|
            classification_history.send("#{key}=", value)
          end
          classification_history.classification_id = item.classification_id
          classification_history.save
        end

        # cc embedded data from other content tables
        embedded_property_names.each do |content_name|
          content_relation = send(content_name)
          content_relation.each_with_index do |content_item, index|
            new_content_history = content_item.to_history(save_time: save_time)
            DataCycleCore::ContentContent::History.create!({
              content_a_history_id: data_set_history.id,
              relation_a: content_name,
              order_a: index,
              content_b_history_id: new_content_history.id,
              content_b_history_type: 'DataCycleCore::Thing::History',
              history_valid: (new_content_history.updated_at...save_time)
            })
          end
        end

        linked_property_names.each do |content_name|
          content_relation = send(content_name)
          content_relation.each_with_index do |content_item, index|
            DataCycleCore::ContentContent::History.create!({
              content_a_history_id: data_set_history.id,
              relation_a: content_name,
              order_a: index,
              content_b_history_id: content_item.id,
              content_b_history_type: 'DataCycleCore::Thing',
              history_valid: (content_item.updated_at...save_time)
            })
          end
        end

        data_set_history.save
        data_set_history
      end
    end
  end
end
