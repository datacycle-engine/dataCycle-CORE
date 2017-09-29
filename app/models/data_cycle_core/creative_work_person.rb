module DataCycleCore
  class CreativeWorkPerson < ApplicationRecord
    include DataSetter

    belongs_to :creative_work
    belongs_to :person

    class History < ApplicationRecord
      belongs_to :creative_work_history, class_name: "DataCycleCore::CreativeWork::History"
      belongs_to :person_history, class_name: "DataCycleCore::Person::History"
    end
  end
end
