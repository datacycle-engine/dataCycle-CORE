# frozen_string_literal: true

module DataCycleCore
  class WatchList < ApplicationRecord
    validates :full_path, presence: true

    scope :by_user, ->(user) { where(user: user) }
    scope :my_selection, -> { unscope(where: :my_selection).where(my_selection: true) }
    scope :without_my_selection, -> { unscope(where: :my_selection).where(my_selection: false) }

    has_many :watch_list_data_hashes, dependent: :delete_all
    has_many :things, through: :watch_list_data_hashes, source: :hashable, source_type: 'DataCycleCore::Thing'
    belongs_to :user

    has_many :watch_list_shares, dependent: :destroy
    has_many :user_groups, through: :watch_list_shares, source: :shareable, source_type: 'DataCycleCore::UserGroup'
    has_many :users, through: :watch_list_shares, source: :shareable, source_type: 'DataCycleCore::User'

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    has_many :activities, as: :activitiable, dependent: :destroy

    before_save :split_full_path, if: :full_path_changed?

    delegate :translated_locales, to: :things
    alias available_locales translated_locales

    def valid_write_links?
      valid_write_links.present?
    end

    def self.fulltext_search(q)
      return all if q.blank?

      all.where('watch_lists.full_path ILIKE ?', "%#{q}%")
    end

    def to_hash
      attributes.except('user_id')
    end

    def clear_if_not_active
      return unless my_selection && !watch_list_data_hashes.where('updated_at >= ?', 12.hours.ago).exists? && watch_list_data_hashes.present?

      watch_list_data_hashes.clear
    end

    def self.conditional_my_selection
      if DataCycleCore::Feature::MySelection.enabled?
        all
      else
        all.where(arel_table[:my_selection].not_eq(true))
      end
    end

<<<<<<< HEAD
=======
    def to_select_option
      DataCycleCore::Filter::SelectOption.new(
        id,
        name,
        model_name.param_key,
        full_path
      )
    end

>>>>>>> old/develop
    private

    def split_full_path
      full_path.squish!
<<<<<<< HEAD
      return self.name = full_path.squish unless DataCycleCore::Feature::CollectionGroup.enabled?

      path_items = full_path.squish.split(DataCycleCore::Feature::CollectionGroup.separator)
=======

      return self.name = full_path unless DataCycleCore::Feature::CollectionGroup.enabled?

      path_items = full_path.split(DataCycleCore::Feature::CollectionGroup.separator)
>>>>>>> old/develop

      self.full_path_names = path_items[0...-1]
      self.name = path_items.last
    end
  end
end
