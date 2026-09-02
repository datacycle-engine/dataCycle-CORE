# frozen_string_literal: true

module DataCycleCore
  class CollectedClassificationContent < ApplicationRecord
    belongs_to :thing, class_name: 'DataCycleCore::Thing'
    belongs_to :classification_alias, class_name: 'DataCycleCore::ClassificationAlias'
    belongs_to :classification_tree_label, class_name: 'DataCycleCore::ClassificationTreeLabel'
    belongs_to :concept, class_name: 'DataCycleCore::Concept', foreign_key: 'classification_alias_id', inverse_of: false
    belongs_to :concept_scheme, class_name: 'DataCycleCore::ConceptScheme', foreign_key: 'classification_tree_label_id', inverse_of: false

    # #47172/#50677: `hidden` marks a row whose concept only reached this content through a mapping
    # while its tree is flagged with hidden_mappings — such rows are excluded from all read paths. The
    # exclusion is baked into the scopes that back the display/API associations
    # (full_/related_classification_contents), and is available explicitly (without_hidden) for the raw
    # collected_classification_contents reads.
    # NB: hidden mappings still reach computed attributes, which resolve them via concept_links
    # (Concept#mapped_concepts / #mapped_inverse_concepts) rather than through CCC.
    scope :without_broader, -> { where(link_type: ['direct', 'related'], hidden: false) }
    scope :related, -> { where(link_type: 'related', hidden: false) }
    scope :without_hidden, -> { where(hidden: false) }
    scope :only_hidden, -> { where(hidden: true) }
    scope :for_scheme, ->(cs_name) { includes(:concept_scheme).where(concept_scheme: { name: cs_name }) }

    def readonly?
      true
    end

    def self.classification_aliases
      DataCycleCore::ClassificationAlias.where(id: pluck(:classification_alias_id))
    end

    def self.concepts
      DataCycleCore::Concept.where(id: pluck(:classification_alias_id))
    end
  end
end
