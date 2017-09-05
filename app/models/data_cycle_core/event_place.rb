module DataCycleCore
  class EventPlace < ApplicationRecord
    include DataSetter

    belongs_to :event
    belongs_to :place
  end
end
