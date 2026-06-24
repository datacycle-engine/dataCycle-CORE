# frozen_string_literal: true

module DataCycleCore
  class ContentContent < ApplicationRecord
    belongs_to :content_a, class_name: 'DataCycleCore::Thing'
    belongs_to :content_b, class_name: 'DataCycleCore::Thing'

    class History < ApplicationRecord
      belongs_to :content_a_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :content_b_history, polymorphic: true
    end

    class Link < ApplicationRecord
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
