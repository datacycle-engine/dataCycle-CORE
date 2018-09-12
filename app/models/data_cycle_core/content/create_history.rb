# frozen_string_literal: true

module DataCycleCore
  module Content
    module CreateHistory
      def to_history(save_time:, current_user: nil, delete: false)
        current_user ||= @current_user
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
        data_set_history.deleted_at = Time.zone.now.to_s(:long_usec) if delete
        data_set_history.created_at = save_time
        data_set_history.updated_at = save_time
        data_set_history.save(touch: false)

        # cc classification_content to history
        classification_content.all.find_each do |item|
          classification_history = DataCycleCore::ClassificationContent::History.new
          classification_history.content_data_history_id = data_set_history.id
          classification_history.content_data_history_type = data_set_history.class.to_s
          item.attributes.except('id', 'content_data_id', 'content_data_type').each do |key, value|
            classification_history.send("#{key}=", value)
          end
          classification_history.classification_id = item.classification_id
          classification_history.save
        end

        # cc embedded data from other content tables
        embedded_relations.each do |content_name|
          content_relation = send(content_name[:name])
          content_relation.each_with_index do |content_item, index|
            new_content_history = content_item.to_history(save_time: save_time, current_user: current_user)
            create_relation_history(new_content_history, data_set_history, content_name, origin_table, index, save_time)
          end
        end

        linked_relations.each do |content_name|
          content_relation = send(content_name[:name])
          content_relation.each_with_index do |content_item, index|
            create_relation_history(content_item, data_set_history, content_name, origin_table, index, save_time)
          end
        end

        data_set_history.save
        data_set_history
      end

      def create_relation_history(content_item, data_set_history, content_name, origin_table, index, save_time)
        content_one_data = [content_item.id, content_item.class.to_s, '', nil]
        content_two_data = [data_set_history.id, data_set_history.class.to_s, content_name[:name], index]
        content_relation_history_data = ['a', 'b'].map { |selector|
          [
            "content_#{selector}_history_id".to_sym,
            "content_#{selector}_history_type".to_sym,
            "relation_#{selector}".to_sym,
            "order_#{selector}".to_sym
          ]
        }.flatten
          .zip(content_name[:table] < origin_table ? content_one_data + content_two_data : content_two_data + content_one_data).to_h
        content_relation_history_data['history_valid'] = (content_item.updated_at...save_time)
        DataCycleCore::ContentContent::History.create!(content_relation_history_data)
      end
    end
  end
end
