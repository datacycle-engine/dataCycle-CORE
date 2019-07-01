# frozen_string_literal: true

module DataCycleCore
  class ClassificationService
    def self.visible_classification_tree?(tree_label, scopes)
      @visible_classification_tree ||= Hash.new do |h, key|
        h[key] = (Array(DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)&.visibility) & Array(scopes)).size.positive?
      end
      @visible_classification_tree["#{tree_label}_#{Array(scopes).join}"]
    end
  end
end
