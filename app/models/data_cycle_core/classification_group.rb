module DataCycleCore
  class ClassificationGroup < ApplicationRecord

    include DataSetter

    belongs_to :external_sources
    belongs_to :classification
    belongs_to :classification_alias

  end
end
