module DataCycleCore
  class UseCase < ApplicationRecord
    belongs_to :user
    belongs_to :external_source
  end
end
