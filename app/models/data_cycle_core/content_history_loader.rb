# frozen_string_literal: true

module DataCycleCore
  module ContentHistoryLoader
    def get_classification_relation(relation_name)
      DataCycleCore::ClassificationContent::History.where(
        'content_data_history_id' => id,
        'content_data_history_type' => self.class.to_s,
        'relation' => relation_name
      )
    end
  end
end
