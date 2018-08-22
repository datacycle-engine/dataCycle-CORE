# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentHistoryLoader
      # def get_classification_relation(relation_name)
      #   DataCycleCore::ClassificationContent::History.where(
      #     'content_data_history_id' => id,
      #     'content_data_history_type' => self.class.to_s,
      #     'relation' => relation_name
      #   )
      # end

      def load_embedded_objects(relation_name)
        target_name = properties_for(relation_name)&.dig('linked_table')
        target_class = "DataCycleCore::#{target_name.classify}::History"
        selector = target_name < self.class.table_name
        content_one_data = [nil, target_class, '']
        content_two_data = [id, self.class.to_s, relation_name]
        where_hash = where_hash_connected_content(selector, content_one_data, content_two_data)

        join_table = selector ? :content_content_a_history : :content_content_b_history
        order_string = selector ? 'content_content_histories.order_b ASC' : 'content_content_histories.order_a ASC'
        target_table_name = "#{target_name.singularize}_history_translations".to_sym

        query = target_class.constantize
        query = query.joins(:translations).where(target_table_name => { locale: I18n.locale })
        query = query.joins(join_table)
        where_hash.each do |key, value|
          query = query.where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["content_content_histories.#{key} = ?", value]))
        end
        query.order(order_string)
      end

      def load_linked_objects(relation_name)
        target_name = properties_for(relation_name)&.dig('linked_table')
        target_class = "DataCycleCore::#{target_name.classify}"
        selector = target_name < self.class.table_name
        content_one_data = [nil, target_class, '']
        content_two_data = [id, self.class.to_s, relation_name]
        where_hash = where_hash_connected_content(selector, content_one_data, content_two_data)

        join_table = selector ? :content_content_a_history : :content_content_b_history
        order_string = selector ? 'content_content_histories.order_b ASC' : 'content_content_histories.order_a ASC' if history?

        query = target_class.constantize
        if DataCycleCore.content_tables.include?(target_name)
          target_table_name = "#{target_name.singularize}_translations".to_sym
          query = query.joins(:translations).where(target_table_name => { locale: I18n.locale })
        end
        query = query.joins(join_table)
        where_hash.each do |key, value|
          query = query.where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["content_content_histories.#{key} = ?", value]))
        end
        query.order(order_string)
      end

      def where_hash_connected_content(selector, content_one_data, content_two_data)
        ['a', 'b'].map { |abselector|
          ["content_#{abselector}_history_id".to_sym,
           "content_#{abselector}_history_type".to_sym,
           "relation_#{abselector}".to_sym]
        }.flatten
          .zip(selector ? content_one_data + content_two_data : content_two_data + content_one_data).to_h.compact
      end

      def load_classifications(relation_name)
        DataCycleCore::Classification
          .joins(:classification_content_histories)
          .where(
            classification_content_histories: {
              content_data_history_type: self.class.to_s,
              content_data_history_id: id,
              relation: relation_name
            }
          )
      end
    end
  end
end
