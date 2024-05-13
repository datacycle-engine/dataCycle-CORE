# frozen_string_literal: true

module DataCycleCore
  class Collection < ApplicationRecord
    TS_QUERY_EXCEPTIONS = /[&|<>\-]/

    validates :type, presence: true

    scope :by_user, ->(user) { where(user:) }
    scope :my_selection, -> { unscope(where: :my_selection).where(my_selection: true) }
    scope :without_my_selection, -> { unscope(where: :my_selection).where(my_selection: false) }

    scope :accessible_by_subclass, lambda { |current_ability|
                                     sub_queries = []
                                     DataCycleCore::Collection.descendants.each do |descendant|
                                       sub_queries << descendant.accessible_by(current_ability).select(:id).reorder(nil).to_sql
                                     end

                                     where("collections.id IN (#{send(:sanitize_sql_array, [sub_queries.join(' UNION ')])})")
                                   }

    scope :by_id_name_slug_description, lambda { |value|
      return all if value.blank?

      raise 'wrong argument type, expected value to be String!' unless value.is_a?(::String)

      return where(id: value) if value.uuid?

      q = value.gsub(TS_QUERY_EXCEPTIONS, '').squish.split.map { |v| "#{v}:*" }.join(' & ')

      where("collections.search_vector @@ to_tsquery('simple', ?)", q)
      .reorder(ActiveRecord::Base.send(:sanitize_sql_for_order, [Arel.sql("ts_rank_cd(collections.search_vector, to_tsquery('simple', ?), 1) DESC"), q]))
    }

    scope :by_id_or_slug, lambda { |value|
                            return none if value.blank?

                            uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
                            slugs = Array.wrap(value).map { |v| v.to_s.strip }
                            queries = []
                            queries.push(default_scoped.where(id: uuids).without_my_selection.select(:id).to_sql) if uuids.present?
                            queries.push(default_scoped.where(slug: slugs).without_my_selection.select(:id).to_sql) if slugs.present?

                            where("collections.id IN (#{send(:sanitize_sql_array, [queries.join(' UNION ')])})")
                          }

    scope :by_id_or_name, lambda { |value|
                            return none if value.blank?

                            uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
                            names = Array.wrap(value).map { |v| v.to_s.strip }
                            queries = []
                            queries.push(default_scoped.where(id: uuids).without_my_selection.select(:id).to_sql) if uuids.present?
                            queries.push(default_scoped.where(name: names).without_my_selection.select(:id).to_sql) if names.present?

                            where("collections.id IN (#{send(:sanitize_sql_array, [queries.join(' UNION ')])})")
                          }

    scope :shared_with_user, lambda { |user|
      includes(:shared_users, :shared_user_groups, :shared_roles)
        .where(shared_users: { id: user.id })
        .or(where(shared_user_groups: { id: user.user_groups.pluck(:id) }))
        .or(where(shared_roles: { id: user.role_id }))
    }
    scope :by_api_user, ->(user) { shared_with_user(user) }

    scope :conditional_my_selection, -> { DataCycleCore::Feature::MySelection.enabled? ? all : without_my_selection }
    scope :named, -> { where.not(name: nil) }

    belongs_to :user
    belongs_to :user_with_deleted, -> { with_deleted }, foreign_key: :user_id, class_name: 'DataCycleCore::User', inverse_of: false

    has_many :activities, as: :activitiable, dependent: :destroy

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item, dependent: :destroy, inverse_of: false

    belongs_to :linked_stored_filter, class_name: 'DataCycleCore::Collection', inverse_of: :filter_uses, dependent: nil
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
    before_save :transform_slug, if: :slug_changed?
    before_save :slug_from_name, if: :slug_from_name?
    before_save :update_description_stripped, if: :description_changed?
    after_save :reload # to load correct slug, as it might get changed in database

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

    private

    def split_full_path
      full_path.squish!

      return self.name = full_path unless DataCycleCore::Feature::CollectionGroup.enabled?

      path_items = full_path.split(DataCycleCore::Feature::CollectionGroup.separator)

      self.full_path_names = path_items[0...-1]
      self.name = path_items.last
    end

    def slug_from_name?
      name_changed? && slug.blank?
    end

    def slug_from_name
      self.slug = name&.to_slug
    end

    def transform_slug
      self.slug = slug&.to_slug
    end

    def update_description_stripped
      self.description_stripped = description&.to_s&.strip_tags
    end
  end
end
