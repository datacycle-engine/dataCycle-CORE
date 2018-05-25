module DataCycleCore
  class WatchList < ApplicationRecord
    validates :headline, presence: true

    scope :by_user, ->(user) { where user: user }

    has_many :watch_list_data_hashes, dependent: :destroy
    belongs_to :user

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    def valid_write_links?
      valid_write_links.present?
    end
  end
end
