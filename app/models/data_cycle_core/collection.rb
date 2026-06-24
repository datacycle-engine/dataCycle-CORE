# frozen_string_literal: true

module DataCycleCore
  class Collection < ApplicationRecord
    validates :type, presence: true
    extend DataCycleCore::Common::TsQueryHelpers
    include DataCycleCore::Common::SlugHelper

    scope :by_user, ->(user) { where(user:) }
    scope :my_selection, -> { unscope(where: :my_selection).where(my_selection: true) }
    scope :without_my_selection, -> { unscope(where: :my_selection).where(my_selection: false) }

    scope :accessible_by_subclass, lambda { |current_ability|
                                     sub_queries = DataCycleCore::Collection.descendants.map do |descendant|
                                       descendant.accessible_by(current_ability).select(:id).reorder(nil).to_sql
                                     end

                                     where("collections.id IN (#{send(:sanitize_sql_array, [sub_queries.join(' UNION ')])})")
                                   }

    scope :by_id_name_slug_description, lambda { |value|
      return all if value.blank?

      raise 'wrong argument type, expected value to be String!' unless value.is_a?(::String)

      return where(id: value) if value.uuid?

      q = text_to_websearch_tsquery(value)

      where("collections.search_vector @@ websearch_to_prefix_tsquery('simple', ?, '')", q)
        .reorder(ActiveRecord::Base.send(:sanitize_sql_for_order, [Arel.sql("ts_rank_cd(collections.search_vector, websearch_to_prefix_tsquery('simple', ?, ''), 5) DESC"), q]))
    }

    scope :by_id_or_slug, lambda { |value|
      return none if value.blank?

      uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
      slugs = Array.wrap(value).map { |v| v.to_s.strip }
      queries = []
      queries.push(default_scoped.where(id: uuids).without_my_selection.select(:id)) if uuids.present?
      queries.push(default_scoped.where(slug: slugs).without_my_selection.select(:id)) if slugs.present?

      query = queries.pop.arel
      query = query.union(queries.pop.arel) if queries.present?

      where(arel_table[:id].in(query))
    }

    scope :by_id_or_name, lambda { |value|
      return none if value.blank?

      uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
      names = Array.wrap(value).map { |v| v.to_s.strip }
      queries = []
      queries.push(default_scoped.where(id: uuids).without_my_selection.select(:id)) if uuids.present?
      queries.push(default_scoped.where(name: names).without_my_selection.select(:id)) if names.present?

      query = queries.pop.arel
      query = query.union(queries.pop.arel) if queries.present?

      where(arel_table[:id].in(query))
    }

    scope :by_id_name_slug, lambda { |value|
      return none if value.blank?

      uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
      slugs = Array.wrap(value).map { |v| v.to_s.strip }

      queries = []
      queries << default_scoped.where(id: uuids).without_my_selection.select(:id).arel if uuids.present?
      queries << default_scoped.where(slug: slugs).without_my_selection.select(:id).arel if slugs.present?
      queries << default_scoped.where(name: slugs).without_my_selection.select(:id).arel if slugs.present?

      query = queries.shift
      query = Arel::Nodes::Union.new(query, queries.shift) while queries.any?

      where(arel_table[:id].in(query))
    }

    scope :shared_with_user_by_user, ->(user) { joins(:shared_users).where(shared_users: { id: user.id }) }
    scope :shared_with_user_by_user_group, ->(user) { joins(:shared_user_groups).where(shared_user_groups: { id: user.user_groups.select(:id) }) }
    scope :shared_with_user_by_role, ->(user) { joins(:shared_roles).where(shared_roles: { id: user.role_id }) }

    scope :conditional_my_selection, -> { DataCycleCore::Feature::MySelection.enabled? ? all : without_my_selection }
    scope :named, -> { where.not(name: nil) }

    belongs_to :user
    belongs_to :user_with_deleted, -> { with_deleted }, foreign_key: :user_id, class_name: 'DataCycleCore::User', inverse_of: false

    has_many :activities, as: :activitiable, dependent: :destroy

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item, dependent: :destroy, inverse_of: false

    belongs_to :linked_stored_filter, class_name: 'DataCycleCore::Collection', inverse_of: :filter_uses
    has_many :filter_uses, class_name: 'DataCycleCore::Collection', foreign_key: :linked_stored_filter_id, inverse_of: :linked_stored_filter, dependent: :nullify

    has_many :collection_shares, dependent: :delete_all
    has_many :shared_users, through: :collection_shares, source: :shareable, source_type: 'DataCycleCore::User'
    has_many :shared_user_groups, through: :collection_shares, source: :shareable, source_type: 'DataCycleCore::UserGroup'
    has_many :shared_roles, through: :collection_shares, source: :shareable, source_type: 'DataCycleCore::Role'

    has_many :collection_concept_scheme_links, class_name: 'DataCycleCore::CollectionConceptSchemeLink', dependent: :delete_all
    has_many :concept_schemes, through: :collection_concept_scheme_links

    has_many :subscriptions, as: :subscribable, dependent: :delete_all
    has_many :content_collection_links, dependent: :delete_all
    has_many :content_collection_link_histories, dependent: :delete_all

    before_save :split_full_path, if: :full_path_changed?
    before_save :transform_slug
    before_save :update_description_stripped, if: :description_changed?
    around_save :retry_on_unique_violation

    def classification_tree_labels
      concept_schemes.pluck(:id)
    end

    def classification_tree_labels=(value)
      self.concept_scheme_ids = value
    end

    def valid_write_links?
      valid_write_links.present?
    end

    def shared_with_user?(user)
      return false if user.nil?

      shared_users.pluck(:id).include?(user.id) ||
        shared_user_groups.pluck(:id).intersect?(user.user_groups.pluck(:id)) ||
        shared_roles.pluck(:id).include?(user.role_id)
    end

    def self.things
      DataCycleCore::Filter::Search.new(locale: nil)
        .union_filter_ids(pluck(:id))
        .query
    end

    def api_v4_type
      'Collection'
    end

    def to_api_v4_json
      {
        '@id': id,
        '@type': ['Collection', api_v4_type],
        name:,
        'dc:slug': slug
      }
    end

    private

    def split_full_path
      full_path.squish!

      return self.name = full_path unless DataCycleCore::Feature::CollectionGroup.enabled?

      path_items = full_path.split(DataCycleCore::Feature::CollectionGroup.separator)

      self.full_path_names = path_items[0...-1]
      self.name = path_items.last
    end

    def transform_slug
      if name_changed? && slug.blank?
        self.slug = name.presence&.to_slug
      elsif slug_changed?
        self.slug = slug.presence&.to_slug
      end
    end

    def update_slug_number
      return if slug.blank?

      base_slug = slug.gsub(/-\d+$/, '')
      first_free_number = first_free_number(base_slug)

      self.slug = first_free_number.nil? ? base_slug : "#{base_slug}-#{first_free_number}"
    end

    def update_description_stripped
      self.description_stripped = description&.to_s&.strip_tags
    end

    def retry_on_unique_violation(&)
      tries = 0

      begin
        tries += 1
        transaction(joinable: false, requires_new: true, &)
      rescue ActiveRecord::RecordNotUnique => e
        raise e if tries >= 3

        Rails.logger.warn("Unique constraint violation on Collection save, retrying (#{tries}/3)...")
        update_slug_number
        retry
      end
    end
  end
end
