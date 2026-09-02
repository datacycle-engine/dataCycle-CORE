# frozen_string_literal: true

module DataCycleCore
  class ClassificationGroup < ApplicationRecord
    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
    belongs_to :classification
    belongs_to :classification_alias

    # Redmine #50677: groups that visibly attach their concept to a content. A mapping group (one
    # whose classification is not the concept's own) does not, when the concept's tree is flagged
    # with hidden_mappings — the same rule collected_classification_contents.hidden materialises,
    # mirrored here for the association-based read paths (see Content::ContentRelations and
    # Utility::Compute::Extensions::PrimaryIconExtension). The concept's own (primary) group always
    # stays visible: a direct classification is not "reached through a mapping".
    #
    # Written as NOT EXISTS instead of a join so it composes with `has_many :through` scopes without
    # adding tables to their join list (a join-table condition there silently defeats scoped
    # preloads of :classification_aliases).
    scope :visible, lambda {
      where(
        <<~SQL.squish
          NOT EXISTS (
            SELECT 1
            FROM concepts
              JOIN concept_schemes ON concept_schemes.id = concepts.concept_scheme_id
            WHERE concepts.id = classification_groups.classification_alias_id
              AND concept_schemes.hidden_mappings
              AND concepts.classification_id IS DISTINCT FROM classification_groups.classification_id
          )
        SQL
      )
    }
  end
end
