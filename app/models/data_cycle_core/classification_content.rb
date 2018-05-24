# frozen_string_literal: true

module DataCycleCore
  class ClassificationContent < ApplicationRecord
    belongs_to :content_data, polymorphic: true
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :content_data_history, polymorphic: true
      belongs_to :classification
    end
  end
end
