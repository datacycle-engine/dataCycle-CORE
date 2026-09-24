# frozen_string_literal: true

module DataCycleCore
  class ConceptLink < ApplicationRecord
    # @see DataCycleCore::Concept::History - same reason, written by
    # delete_concept_links_to_histories_trigger.
    class History < ApplicationRecord
      belongs_to :parent, class_name: 'Concept', optional: true
      belongs_to :child, class_name: 'Concept', optional: true

      def readonly?
        true
      end
    end

    LINK_TYPE_BROADER = 'broader'
    LINK_TYPE_RELATED = 'related'
    LINK_TYPES = [LINK_TYPE_BROADER, LINK_TYPE_RELATED].freeze

    # Every concept is reachable through exactly one `broader` link, and a root's carries no parent:
    # concept_paths and update_concepts_order_a both start their walk at the link whose parent_id is
    # NULL, so a root without one would have neither a path nor an order.
    belongs_to :parent, class_name: 'Concept', optional: true
    belongs_to :child, class_name: 'Concept'

    validates :link_type, inclusion: { in: LINK_TYPES }
    validate :child_distinct_from_parent

    scope :broader, -> { where(link_type: LINK_TYPE_BROADER) }
    scope :related, -> { where(link_type: LINK_TYPE_RELATED) }

    # Redmine #50677: a `related` link attaches its parent concept to every content its child
    # classifies, and stops doing so visibly once the parent's scheme is flagged with
    # hidden_mappings - the same rule collected_concept_contents.hidden materialises, mirrored here
    # for the association-based read paths (see Content::ContentRelations and
    # Utility::Compute::Extensions::PrimaryIconExtension). A `broader` link is tree structure, never a
    # mapping, so it stays visible.
    #
    # Written as NOT EXISTS instead of a join so it composes with `has_many :through` scopes without
    # adding tables to their join list (a join-table condition there silently defeats scoped preloads
    # of :concepts).
    scope :visible, lambda {
      where(
        <<~SQL.squish
          concept_links.link_type <> '#{LINK_TYPE_RELATED}'
          OR NOT EXISTS (
            SELECT 1
            FROM concepts
              JOIN concept_schemes ON concept_schemes.id = concepts.concept_scheme_id
            WHERE concepts.id = concept_links.parent_id
              AND concept_schemes.hidden_mappings
          )
        SQL
      )
    }

    private

    def child_distinct_from_parent
      errors.add(:child_id, "can't be same as parent_id") if parent_id.present? && child_id.present? && parent_id == child_id
    end
  end
end
