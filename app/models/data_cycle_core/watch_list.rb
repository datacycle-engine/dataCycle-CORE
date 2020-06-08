# frozen_string_literal: true

module DataCycleCore
  class WatchList < ApplicationRecord
    validates :name, presence: true

    scope :by_user, ->(user) { where user: user }

    has_many :watch_list_data_hashes, dependent: :delete_all
    has_many :things, through: :watch_list_data_hashes, source: :hashable, source_type: 'DataCycleCore::Thing'
    belongs_to :user

    has_many :watch_list_shares, dependent: :destroy
    has_many :user_groups, through: :watch_list_shares, source: :shareable, source_type: 'DataCycleCore::UserGroup'
    has_many :users, through: :watch_list_shares, source: :shareable, source_type: 'DataCycleCore::User'

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    has_many :activities, as: :activitiable, dependent: :destroy

    def valid_write_links?
      valid_write_links.present?
    end
  end
end
