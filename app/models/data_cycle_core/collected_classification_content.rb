# frozen_string_literal: true

module DataCycleCore
  class CollectedClassificationContent < ApplicationRecord
    belongs_to :thing, class_name: 'DataCycleCore::Thing'
    belongs_to :classification_alias, class_name: 'DataCycleCore::ClassificationAlias'
    belongs_to :classification_tree_label, class_name: 'DataCycleCore::ClassificationTreeLabel'
    belongs_to :concept, class_name: 'DataCycleCore::Concept', foreign_key: 'classification_alias_id', inverse_of: false
    belongs_to :concept_scheme, class_name: 'DataCycleCore::ConceptScheme', foreign_key: 'classification_tree_label_id', inverse_of: false

    scope :without_broader, -> { where(link_type: ['direct', 'related']) }
    scope :direct, -> { where(link_type: 'direct') }

    def readonly?
      true
    end

    def self.classification_aliases
      DataCycleCore::ClassificationAlias.where(id: pluck(:classification_alias_id))
    end
  end
end
