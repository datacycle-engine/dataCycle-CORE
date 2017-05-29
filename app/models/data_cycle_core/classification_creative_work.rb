module DataCycleCore
  class ClassificationCreativeWork < ApplicationRecord

    include DataSetter

    belongs_to :creative_work
    belongs_to :classification

  end
end
