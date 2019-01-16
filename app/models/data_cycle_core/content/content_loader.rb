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
        load_relation(relation_name)
      end

      def load_embedded_objects(relation_name)
        load_relation(relation_name)
      end

      def load_relation(relation_name)
        relation_contents = DataCycleCore::Thing
          .joins(:content_content_b)
          .where({
            content_contents: {
              content_a_id: id,
              relation_a: relation_name
            }
          })
        relation_contents = relation_contents.joins(:translations).where(thing_translations: { locale: I18n.locale }) unless schema&.dig('properties', relation_name, 'linked_language') == 'all'
        relation_contents.order('content_contents.order_a ASC')
      end

      def load_classifications(relation_name)
        DataCycleCore::Classification
          .joins(:classification_contents)
          .where(
            classification_contents: {
              content_data_id: id, relation: relation_name
            }
          )
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::Classification
          .joins(classification_aliases: [classification_tree: [:classification_tree_label]])
          .where(
            classification_tree_labels: { name: tree_label },
            classification_aliases: { name: alias_name }
          ).first!
      end

      def as_of(timestamp)
        return self if updated_at.blank? || timestamp.blank? || timestamp >= updated_at

        history_table = DataCycleCore::Thing::History.arel_table
        history_table_translation = DataCycleCore::Thing::History::Translation.arel_table

        return_data = histories.joins(
          history_table
            .join(history_table_translation)
            .on(history_table[:id].eq(history_table_translation[:thing_history_id]))
            .join_sources
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
