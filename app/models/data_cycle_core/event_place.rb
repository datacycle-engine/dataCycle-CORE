module DataCycleCore
  class EventPlace < ApplicationRecord

    belongs_to :event
    belongs_to :place

    class History < ApplicationRecord
      belongs_to :event_history, class_name: "DataCycleCore::Event::History"
      belongs_to :place_history, class_name: "DataCycleCore::Place::History"
    end
  end
end
