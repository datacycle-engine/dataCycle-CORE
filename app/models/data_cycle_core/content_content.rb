# frozen_string_literal: true

module DataCycleCore
  class ContentContent < ApplicationRecord
    belongs_to :content_a, class_name: 'DataCycleCore::Thing'
    belongs_to :content_b, class_name: 'DataCycleCore::Thing'

    class History < ApplicationRecord
      belongs_to :content_a_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :content_b_history, polymorphic: true
    end

    # content_content_links carries no primary key, only the content_content_links_uq_constraint
    # over these four columns, so order dependent finders have nothing to sort by:
    #
    # Before Rails 8.1, `Link.first` ran as `SELECT ... LIMIT 1` and returned an arbitrary row.
    # Rails 8.1 would raise MissingRequiredOrderError, so we name the columns AR sorts by when
    # a relation carries no order of its own - the role a primary key normally fills silently.
    class Link < ApplicationRecord
      self.implicit_order_column = [:content_content_id, :content_a_id, :content_b_id, :relation]

      belongs_to :content_a, class_name: 'DataCycleCore::Thing'
      belongs_to :content_b, class_name: 'DataCycleCore::Thing'
      belongs_to :content_content_id, class_name: 'DataCycleCore::ContentContent'

      scope :with_relation, -> { where.not(relation: nil) }

      def self.id_attribute_hash(content_b_id)
        dependent_ids = with_relation.where(content_b_id:).distinct.pluck(:content_a_id, :relation)
        return {} if dependent_ids.blank?

        id_attribute_hash = Hash.new { |h, k| h[k] = [] }
        dependent_ids.each do |dep_id, prop_name|
          id_attribute_hash[dep_id] << prop_name
        end

        id_attribute_hash
      end
    end
  end
end
