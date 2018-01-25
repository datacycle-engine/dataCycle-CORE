module DataCycleCore
  class WatchList < ApplicationRecord
    validates :headline, presence: true

    scope :by_user, ->(user) { where user: user }

    has_many :watch_list_data_hashes, dependent: :destroy
    belongs_to :user

    has_many :data_links, as: :item
  end
end
