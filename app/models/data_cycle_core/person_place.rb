module DataCycleCore
  class PersonPlace < ApplicationRecord

    belongs_to :person
    belongs_to :place

    class History < ApplicationRecord
      belongs_to :person_history, class_name: "DataCycleCore::Person::History"
      belongs_to :place_history, class_name: "DataCycleCore::Place::History"
    end
  end
end
