module DataCycleCore
  class ClassificationCreativeWorkHistory < ApplicationRecord
    belongs_to :creative_work_history
    belongs_to :classification
  end
end
