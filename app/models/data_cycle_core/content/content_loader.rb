# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentLoader
      def get_data_hash(timestamp = Time.zone.now)
        return if !translated_locales.include?(I18n.locale) && changes.count.zero? # for new data-sets with pending data in it
        as_of(timestamp).try(:to_h, timestamp)
      end

      def diff(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template).diff_hash
      end

      def diff?(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        differ.diff?(a: get_data_hash, schema_a: schema, b: data, schema_b: template)
      end

      def load_linked_objects(relation_name)
        target_name = properties_for(relation_name)&.dig('linked_table')
        target_class = "DataCycleCore::#{target_name.classify}"
        selector = target_name < self.class.table_name
        content_one_data = [nil, target_class, '']
        content_two_data = [id, self.class.to_s, relation_name]
        where_hash = where_hash_connected_content(selector, content_one_data, content_two_data)
        join_table = selector ? :content_content_a : :content_content_b
        order_string = selector ? 'content_contents.order_b ASC' : 'content_contents.order_a ASC'

        query = target_class.constantize
        if DataCycleCore.content_tables.include?(target_name)
          target_table_name = "#{target_name.singularize}_translations".to_sym
          query = query.joins(:translations).where(target_table_name => { locale: I18n.locale })
        end
        query = query.joins(join_table)
        where_hash.each do |key, value|
          query = query.where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["content_contents.#{key} = ?", value]))
        end
        query.order(order_string)
      end

      def load_embedded_objects(relation_name)
        target_name = properties_for(relation_name)&.dig('linked_table')
        target_class = "DataCycleCore::#{target_name.classify}"
        selector = target_name < self.class.table_name
        content_one_data = [nil, target_class, '']
        content_two_data = [id, self.class.to_s, relation_name]
        where_hash = where_hash_connected_content(selector, content_one_data, content_two_data)

        join_table = selector ? :content_content_a : :content_content_b
        order_string = selector ? 'content_contents.order_b ASC' : 'content_contents.order_a ASC'
        target_table_name = "#{target_name.singularize}_translations".to_sym

        query = target_class.constantize
        query = query.joins(:translations).where(target_table_name => { locale: I18n.locale })
        query = query.joins(join_table)
        where_hash.each do |key, value|
          query = query.where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["content_contents.#{key} = ?", value]))
        end
        query.order(order_string)
      end

      def where_hash_connected_content(selector, content_one_data, content_two_data)
        ['a', 'b'].map { |abselector|
          ["content_#{abselector}_id".to_sym,
           "content_#{abselector}_type".to_sym,
           "relation_#{abselector}".to_sym]
        }.flatten
          .zip(selector ? content_one_data + content_two_data : content_two_data + content_one_data).to_h.compact
      end

      def load_classifications(relation_name)
        DataCycleCore::Classification.joins(:classification_contents)
          .where(classification_contents: { content_data_type: self.class.to_s, content_data_id: id, relation: relation_name })
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
          .where(classification_tree_labels: { name: tree_label }, classification_aliases: { name: alias_name }).first!
      end

      def load_template(table_name, template_name)
        ('DataCycleCore::' + table_name.classify).constantize
          .find_by(template: true, template_name: template_name)
      end

      def as_of(timestamp)
        return self if updated_at.blank? || timestamp.blank? || timestamp >= updated_at

        base_content_class = self.class.to_s
        history_table = "#{base_content_class}::History".safe_constantize.arel_table
        history_table_translation = "#{base_content_class}::History::Translation".safe_constantize.arel_table
        history_id = "#{base_content_class}::History".safe_constantize.table_name.singularize.foreign_key.to_sym

        return_data = histories.joins(
          history_table.join(history_table_translation).on(history_table[:id].eq(history_table_translation[history_id])).join_sources
        ).where(
          in_range(history_table_translation, timestamp)
        ).order(history_table_translation[:history_valid])
        return_data.last
      end

      def in_range(table_name, timestamp)
        Arel::Nodes::InfixOperation.new(
          '@>',
          table_name[:history_valid],
          Arel::Nodes::SqlLiteral.new("CAST('#{timestamp.to_s(:long_usec)}' AS TIMESTAMP WITH TIME ZONE)")
        )
      end
    end
  end
end
