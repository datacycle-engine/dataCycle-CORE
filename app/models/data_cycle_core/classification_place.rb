module DataCycleCore
  class ClassificationPlace < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    belongs_to :classification
    belongs_to :place

    class History < ApplicationRecord
      belongs_to :place_history
      belongs_to :classification
    end

  end
end
