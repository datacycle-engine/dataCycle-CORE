module DataCycleCore
  class ClassificationsCreativeWork < ApplicationRecord

    include DataSetter

    belongs_to :creative_work
    belongs_to :classifications_alias

  end
end
