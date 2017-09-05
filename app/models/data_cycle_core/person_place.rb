module DataCycleCore
  class PersonPlace < ApplicationRecord
    include DataSetter

    belongs_to :person
    belongs_to :place
  end
end
