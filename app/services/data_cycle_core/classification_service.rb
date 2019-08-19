# frozen_string_literal: true

module DataCycleCore
  class ClassificationService
    def self.visible_classification_tree?(tree_label, scopes)
      tree_label_visibility = Rails.cache.fetch("#{tree_label}_visibilty", expires_in: 5.minutes) { Array(DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)&.visibility) }
      (tree_label_visibility & Array(scopes)).size.positive?
    end
  end
end
