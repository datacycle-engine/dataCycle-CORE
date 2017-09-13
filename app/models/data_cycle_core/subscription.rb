module DataCycleCore
  class Subscription < ApplicationRecord

    belongs_to :user
    belongs_to :subscribable, polymorphic: true

    scope :by_user, -> (user) { where(user_id: user.id) }
  end
end
