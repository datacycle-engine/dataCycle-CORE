# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module UtilityFunctions
        def load_default_values(data_hash)
          return nil if data_hash.blank?
          return_data = {}
          data_hash.each do |key, value|
            return_data[key] = default_classification(value.symbolize_keys)
          end
          return_data.reject { |_, value| value.blank? }
        end

        def load_template(target_type, template_name)
          I18n.with_locale(:de) do
            target_type.find_by!(template: true, template_name: template_name)
          end
        rescue ActiveRecord::RecordNotFound
          raise "Missing template #{template_name} for #{target_type}"
        end

        def default_classification(value:, tree_label:)
          [
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })&.first&.id
          ].reject(&:nil?)
        end
      end
    end
  end
end
