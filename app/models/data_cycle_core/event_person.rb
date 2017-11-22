module DataCycleCore
  class EventPerson < ApplicationRecord

    belongs_to :event
    belongs_to :person

    class History < ApplicationRecord
      belongs_to :event_history, class_name: "DataCycleCore::Event::History"
      belongs_to :person_history, class_name: "DataCycleCore::Person::History"
    end
  end
end
