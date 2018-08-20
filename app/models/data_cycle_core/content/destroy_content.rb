# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content
        to_history(save_time: Time.zone.now, delete: true) unless history?
        destroy_children(true)
      end

      def destroy_children(delete_relation)
        embedded_property_names.each do |name|
          definition = property_definitions[name]

          delete = false
          # delete = definition['delete'] unless definition['delete'].blank?
          delete = true if history? || definition['type'] == 'embedded'

          relation_name = definition['linked_table']
          if delete
            load_embedded_objects(relation_name, name).each do |item|
              item.destroy_children(delete)
              item.destroy
            end
          else
            relation_class = history? ? DataCycleCore::ContentContent::History : DataCycleCore::ContentContent
            target_class = history? ? "DataCycleCore::#{relation_name.classify}::History" : "DataCycleCore::#{relation_name.classify}"
            content_one_data = [method(relation_name).call.ids, target_class, '']
            content_two_data = [id, self.class.to_s, name]
            where_hash = ['a', 'b'].map { |selector|
              if history?
                ["content_#{selector}_history_id".to_sym,
                 "content_#{selector}_history_type".to_sym,
                 "relation_#{selector}".to_sym]
              else
                ["content_#{selector}_id".to_sym,
                 "content_#{selector}_type".to_sym,
                 "relation_#{selector}".to_sym]
              end
            }.flatten
              .zip(relation_name < self.class.table_name ? content_one_data + content_two_data : content_two_data + content_one_data).to_h
            relations = relation_class.where(where_hash)
            relations.destroy_all if relations.present?
          end
        end

        # cleanup classification_relation (only if present item can be deleted)
        return unless delete_relation
        classification_property_names.each do |classification_name|
          content_relation = get_classification_relation(classification_name)
          content_relation.destroy_all if content_relation.present?
        end
      end
    end
  end
end
