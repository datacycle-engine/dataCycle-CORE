module DataCycleCore
  class WatchList < ApplicationRecord
    validates :headline, presence: true

    scope :by_user, ->(user) { where user: user }

    has_many :watch_list_data_hashes, dependent: :destroy
    belongs_to :user

    has_many :data_links, as: :item, dependent: :destroy

    def valid_write_links?
      data_links.valid.where(permissions: 'write').present?
    end
  end
end
