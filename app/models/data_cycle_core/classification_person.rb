module DataCycleCore
  class ClassificationPerson < ApplicationRecord

    include DataSetter

    belongs_to :person
    belongs_to :classification

  end
end
