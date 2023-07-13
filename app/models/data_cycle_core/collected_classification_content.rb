# frozen_string_literal: true

module DataCycleCore
  class CollectedClassificationContent < ApplicationRecord
    belongs_to :thing, class_name: 'DataCycleCore::Thing'
    belongs_to :classification_alias, class_name: 'DataCycleCore::ClassificationAlias'
    belongs_to :classification_tree_label, class_name: 'DataCycleCore::ClassificationTreeLabel'
  end
end
