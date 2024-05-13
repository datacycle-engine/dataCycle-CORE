# frozen_string_literal: true

module DataCycleCore
  class ClassificationService
    def self.visible_classification_tree?(tree_label, scopes)
      tree_label_name = tree_label.is_a?(DataCycleCore::ClassificationTreeLabel) ? tree_label.name : tree_label
      tree_label_visibility = Rails.cache.fetch("#{tree_label_name}_visibilty", expires_in: 5.minutes) do
        tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label) unless tree_label.is_a?(DataCycleCore::ClassificationTreeLabel)
        Array.wrap(tree_label&.visibility)
      end
      (tree_label_visibility & Array(scopes)).size.positive?
    end
  end
end
