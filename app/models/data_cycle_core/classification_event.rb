module DataCycleCore
  class ClassificationEvent < ApplicationRecord

    include DataSetter

    belongs_to :event
    belongs_to :classification

  end
end
