# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentLoader
      def get_classification_relation(relation_name)
        DataCycleCore::ClassificationContent.where(
          'content_data_id' => id,
          'content_data_type' => self.class.to_s,
          'relation' => relation_name
        )
      end

      def get_asset_relation(relation_name)
        DataCycleCore::AssetContent.where(
          'content_data_id' => id,
          'content_data_type' => self.class.to_s,
          'relation' => relation_name
        )
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
          .where(classification_tree_labels: { name: tree_label }, classification_aliases: { name: alias_name }).first!
      end

      def load_template(table_name, template_name)
        ('DataCycleCore::' + table_name.classify).constantize
          .find_by(template: true, template_name: template_name)
      end
    end
  end
end
