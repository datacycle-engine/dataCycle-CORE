module DataCycleCore
  class ClassificationUserGroup < ApplicationRecord

    belongs_to :classification
    belongs_to :user_group

  end
end
