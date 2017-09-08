module DataCycleCore
  class ClassificationEvent < ApplicationRecord

    include DataSetter

    belongs_to :event
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :event_history
      belongs_to :classification
    end

  end
end
