module DataCycleCore
  class ClassificationsGroup < ApplicationRecord

    include DataSetter

    belongs_to :external_sources
    belongs_to :classification
    belongs_to :classifications_alias

  end
end
