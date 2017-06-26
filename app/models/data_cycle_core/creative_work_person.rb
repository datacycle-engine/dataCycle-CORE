module DataCycleCore
  class CreativeWorkPerson < ApplicationRecord
    include DataSetter

    belongs_to :creative_work
    belongs_to :person
  end
end
