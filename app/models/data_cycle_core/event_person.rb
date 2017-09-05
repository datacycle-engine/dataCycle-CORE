module DataCycleCore
  class EventPerson < ApplicationRecord
    include DataSetter

    belongs_to :event
    belongs_to :person
  end
end
