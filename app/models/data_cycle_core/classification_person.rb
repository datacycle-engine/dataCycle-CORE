module DataCycleCore
  class ClassificationPerson < ApplicationRecord

    include DataSetter

    belongs_to :person
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :person_history
      belongs_to :classification
    end
    
  end
end
