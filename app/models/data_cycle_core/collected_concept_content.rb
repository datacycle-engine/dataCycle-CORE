# frozen_string_literal: true

module DataCycleCore
  class CollectedConceptContent < ApplicationRecord
    belongs_to :thing, class_name: 'DataCycleCore::Thing'
    belongs_to :concept
    belongs_to :concept_scheme

    # #47172/#50677: `hidden` marks a row whose concept only reached this content through a mapping
    # while its scheme is flagged with hidden_mappings - such rows are excluded from all read paths. The
    # exclusion is baked into the scopes that back the display/API associations
    # (full_/related_concept_contents), and is available explicitly (without_hidden) for the raw
    # collected_concept_contents reads.
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

    def self.concepts
      DataCycleCore::Concept.where(id: pluck(:concept_id))
    end
  end
end
