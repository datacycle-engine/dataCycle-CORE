module DataCycleCore
  class CreativeWorkPlace < ApplicationRecord
    include DataSetter

    belongs_to :creative_work
    belongs_to :place
  end
end
