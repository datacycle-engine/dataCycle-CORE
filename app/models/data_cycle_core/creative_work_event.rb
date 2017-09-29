module DataCycleCore
  class CreativeWorkEvent < ApplicationRecord
    include DataSetter

    belongs_to :creative_work
    belongs_to :event

    class History < ApplicationRecord
      belongs_to :creative_work_history, class_name: "DataCycleCore::CreativeWork::History"
      belongs_to :event_history, class_name: "DataCycleCore::Event::History"
    end
  end
end
