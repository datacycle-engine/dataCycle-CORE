module DataCycleCore
  class CreativeWorksPlace < ActiveRecord::Base
    include DataSetter

    belongs_to :creative_work
    belongs_to :place
  end
end 
