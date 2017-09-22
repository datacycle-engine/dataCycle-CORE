module DataCycleCore
  class ClassificationCreativeWork < ApplicationRecord

    include DataSetter

    belongs_to :creative_work
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :creative_work_history
      belongs_to :classification
    end

  end
end
