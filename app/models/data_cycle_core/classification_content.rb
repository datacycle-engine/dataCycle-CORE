# frozen_string_literal: true

module DataCycleCore
  class ClassificationContent < ApplicationRecord
    belongs_to :content_data, class_name: 'DataCycleCore::Thing'
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :content_data_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :classification
    end

    class << self
      def with_content(content_data_id)
        where(content_data_id:)
      end

      def with_relation(relation_name)
        where(relation: relation_name)
      end

      def with_classification_ids(ids)
        where(classification_id: ids)
      end

      def classifications
        DataCycleCore::Classification.where(id: pluck(:classification_id))
      end
    end
  end
end
