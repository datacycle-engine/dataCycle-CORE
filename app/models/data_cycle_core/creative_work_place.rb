module DataCycleCore
  class CreativeWorkPlace < ApplicationRecord
    include DataSetter

    belongs_to :creative_work
    belongs_to :place

    class History < ApplicationRecord
      belongs_to :creative_work_history, class_name: "DataCycleCore::CreativeWork::History"
      belongs_to :place_history, class_name: "DataCycleCore::Place::History"
    end
  end
end
