module DataCycleCore
  class ClassificationPlace < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    belongs_to :classification
    belongs_to :place

  end
end
