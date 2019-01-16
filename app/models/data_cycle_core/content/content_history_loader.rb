# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentHistoryLoader
      def get_data_hash(timestamp = nil)
        return if !translated_locales.include?(I18n.locale) && changes.count.zero? # for new data-sets with pending data in it
        timestamp ||= history_valid.first + (history_valid.last - history_valid.first) / 2
        as_of(timestamp).try(:to_h, timestamp)
      end

      def diff(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        timestamp ||= history_valid.first + (history_valid.last - history_valid.first) / 2
        differ.diff(a: get_data_hash(timestamp), schema_a: schema, b: data, schema_b: template).diff_hash
      end

      def diff?(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        timestamp ||= history_valid.first + (history_valid.last - history_valid.first) / 2
        differ.diff?(a: get_data_hash(timestamp), schema_a: schema, b: data, schema_b: template)
      end

      def load_linked_objects(relation_name)
        relation_contents = DataCycleCore::Thing
          .joins(:content_content_b_history)
          .where({
            content_content_histories: {
              content_a_history_id: id,
              relation_a: relation_name,
              content_b_history_type: 'DataCycleCore::Thing'
            }
          })
        relation_contents = relation_contents.joins(:translations).where(thing_translations: { locale: I18n.locale }) unless schema&.dig('properties', relation_name, 'linked_language') == 'all'
        relation_contents.order('content_content_histories.order_a ASC')
      end

      def load_embedded_objects(relation_name)
        relation_contents = DataCycleCore::Thing::History
          .joins(:content_content_b_history)
          .where({
            content_content_histories: {
              content_a_history_id: id,
              relation_a: relation_name,
              content_b_history_type: 'DataCycleCore::Thing::History'
            }
          })
        relation_contents = relation_contents.joins(:translations).where(thing_history_translations: { locale: I18n.locale }) unless schema&.dig('properties', relation_name, 'linked_language') == 'all'
        relation_contents.order('content_content_histories.order_a ASC')
      end

      def load_classifications(relation_name)
        DataCycleCore::Classification
          .joins(:classification_content_histories)
          .where(
            classification_content_histories: {
              content_data_history_id: id,
              relation: relation_name
            }
          )
      end

      def as_of(timestamp)
        content_table_id = self.class.table_name.split('_')[0..-2].join('_').foreign_key
        history_table_translation = "#{self.class}::Translation".safe_constantize.arel_table

        return_data = self.class.joins(:translations)
          .where(content_table_id => send(content_table_id))
          .where(
            Arel::Nodes::InfixOperation.new(
              '@>',
              history_table_translation[:history_valid],
              Arel::Nodes::SqlLiteral.new("CAST('#{timestamp.to_s(:long_usec)}' AS TIMESTAMP WITH TIME ZONE)")
            )
          ).order(history_table_translation[:history_valid])
        return_data.last
      end
    end
  end
end
