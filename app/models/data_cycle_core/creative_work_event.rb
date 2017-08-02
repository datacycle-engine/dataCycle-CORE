module DataCycleCore
  class CreativeWorkEvent < ApplicationRecord
    include DataSetter

    belongs_to :creative_work
    belongs_to :event
  end
end
