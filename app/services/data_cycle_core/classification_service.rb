# frozen_string_literal: true

module DataCycleCore
  class ClassificationService
    def self.visible_classification_tree?(tree_label, scopes)
      (Array(DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)&.visibility) & Array(scopes)).size.positive?
    end
  end
end
