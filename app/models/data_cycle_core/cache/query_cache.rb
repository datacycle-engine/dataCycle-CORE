# frozen_string_literal: true

module DataCycleCore
  module Cache
    module QueryCache
      class << self
        def load_template(target_type, template_name)
          Rails.cache.fetch("#{target_type.table_name}/template/#{template_name}", expires_in: 30.seconds) do
            I18n.with_locale(:de) do
              target_type.find_by!(template: true, template_name: template_name)
            end
          end
        end

        def load_classifications_from_tree(tree_label, value)
          Rails.cache.fetch("#{classifications}/#{tree_label}/classification/#{value}", expires_in: 5.minutes) do
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })
          end
        end
      end
    end
  end
end
