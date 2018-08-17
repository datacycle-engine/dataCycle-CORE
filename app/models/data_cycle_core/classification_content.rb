# frozen_string_literal: true

module DataCycleCore
  class ClassificationContent < ApplicationRecord
    belongs_to :content_data, polymorphic: true
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :content_data_history, polymorphic: true
      belongs_to :classification
    end

    def for_content(content_data_id, content_data_type)
      where(content_data_id: content_data_id, content_data_type: content_data_type)
    end

    def for_relation(relation_name)
      where(relation: relation_name)
    end

    def for_classification_ids(ids)
      where(classification_id: ids)
    end
  end
end
