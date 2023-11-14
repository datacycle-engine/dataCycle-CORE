# frozen_string_literal: true

module DataCycleCore
  class WatchList < ApplicationRecord
    validates :full_path, presence: true

    default_scope { includes(:collection_configuration) }

    scope :by_user, ->(user) { where(user:) }
    scope :my_selection, -> { unscope(where: :my_selection).where(my_selection: true) }
    scope :without_my_selection, -> { unscope(where: :my_selection).where(my_selection: false) }

    has_many :watch_list_data_hashes, dependent: :delete_all
    has_many :things, through: :watch_list_data_hashes, source: :hashable, source_type: 'DataCycleCore::Thing'
    belongs_to :user

    has_many :watch_list_shares, dependent: :destroy
    has_many :user_groups, through: :watch_list_shares, source: :shareable, source_type: 'DataCycleCore::UserGroup'
    has_many :users, through: :watch_list_shares, source: :shareable, source_type: 'DataCycleCore::User'

    has_many :subscriptions, as: :subscribable, dependent: :destroy

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    has_many :activities, as: :activitiable, dependent: :destroy

    has_one :collection_configuration
    accepts_nested_attributes_for :collection_configuration, update_only: true
    delegate :slug, to: :collection_configuration, allow_nil: true

    before_save :split_full_path, if: :full_path_changed?
    before_save :update_slug, if: :update_slug?

    delegate :translated_locales, to: :things
    alias available_locales translated_locales

    def self.watch_list_data_hashes
      return DataCycleCore::WatchListDataHash.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::WatchListDataHash.where(watch_list_id: all.select(:id))
    end

    def self.by_id_or_slug(value)
      return none if value.blank?

      uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
      slugs = Array.wrap(value)
      queries = []
      queries.push(unscoped.where(id: uuids).select(:id).to_sql) if uuids.present?
      queries.push(DataCycleCore::CollectionConfiguration.where.not(watch_list_id: nil).where(slug: slugs).select(:watch_list_id).to_sql) if slugs.present?

      where("watch_lists.id IN (#{send(:sanitize_sql_array, [queries.join(' UNION ')])})")
    end

    def valid_write_links?
      valid_write_links.present?
    end

    def notify_subscribers(current_user, content_ids, type)
      return if content_ids.blank?

      DataCycleCore::WatchListSubscriberNotificationJob.perform_later(self, current_user, content_ids, type) if subscriptions.except_user_id(current_user.id).exists?
    end

    def self.fulltext_search(q)
      return all if q.blank?

      all.where('watch_lists.full_path ILIKE ?', "%#{q}%")
    end

    def to_hash
      attributes.except('user_id')
    end

    def clear_if_not_active
      return unless my_selection && !watch_list_data_hashes.exists?(['updated_at >= ?', 12.hours.ago]) && watch_list_data_hashes.present?

      watch_list_data_hashes.clear
    end

    def self.conditional_my_selection
      if DataCycleCore::Feature::MySelection.enabled?
        all
      else
        all.where(arel_table[:my_selection].not_eq(true))
      end
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id,
        ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon watch_list-icon'),
          name
        ].compact, ' '),
        model_name.param_key,
        "#{model_name.human(count: 1, locale:)}: #{full_path}"
      )
    end

    def add_things_from_query(contents_query)
      ids = ActiveRecord::Base.connection.execute <<-SQL.squish
        INSERT INTO watch_list_data_hashes (watch_list_id, hashable_id, hashable_type)
        #{contents_query.select("'#{id}', things.id, 'DataCycleCore::Thing'").to_sql}
        ON CONFLICT DO NOTHING
        RETURNING hashable_id;
      SQL

      update_column(:updated_at, Time.zone.now)

      ids.pluck('hashable_id')
    end

    def delete_all_watch_list_data_hashes
      ids = ActiveRecord::Base.connection.execute <<-SQL.squish
        DELETE FROM watch_list_data_hashes
        WHERE watch_list_data_hashes.watch_list_id = '#{id}'
        RETURNING hashable_id;
      SQL

      update_column(:updated_at, Time.zone.now)

      ids.pluck('hashable_id')
    end

    def update_order_by_array(order_array)
      return if order_array.blank?

      update_column(:updated_at, Time.zone.now)
      update_column(:manual_order, true) unless manual_order

      watch_list_data_hashes
        .where(hashable_id: order_array)
        .update_all(['order_a = array_position(ARRAY[?]::uuid[], hashable_id)', order_array])
    end

    private

    def split_full_path
      full_path.squish!

      return self.name = full_path unless DataCycleCore::Feature::CollectionGroup.enabled?

      path_items = full_path.split(DataCycleCore::Feature::CollectionGroup.separator)

      self.full_path_names = path_items[0...-1]
      self.name = path_items.last
    end

    def update_slug?
      name_changed? && slug.blank?
    end

    def update_slug
      self.collection_configuration_attributes = { slug: name&.to_slug }
    end
  end
end
