# frozen_string_literal: true

module DataCycleCore
  class UserGroup < ApplicationRecord
    validates :name, presence: true

    has_many :user_group_users, dependent: :destroy
    has_many :users, through: :user_group_users
    attribute :permissions, :jsonb, default: -> { [] }

    has_many :collection_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :shared_collections, through: :collection_shares, source: :collection

    has_many :classification_user_groups, dependent: :destroy
    has_many :classifications, through: :classification_user_groups
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where(classification_aliases: { internal: false }) }, through: :classification_groups, source: :classification_alias

    scope :fulltext_search, lambda { |search_term|
                              where(search_term.to_s.split.map { |term| sanitize_sql_for_conditions(["concat_ws(' ', #{search_columns.join(', ')}) ILIKE ?", "%#{term.strip}%"]) }.join(' AND '))
                            }

    scope :user_groups_with_permission, ->(key) { key.blank? ? none : where('permissions ? :key', key:) }

    DataCycleCore::Feature::UserGroupClassification.attribute_relations.each do |key, config|
      has_many key.to_sym, -> { for_tree(config['tree_label']) }, through: :classification_groups, source: :classification_alias

      define_singleton_method key.to_sym do
        classification_aliases.includes(:classification_tree_label).where(classification_tree_labels: { name: config['tree_label'] })
      end
    end

    def self.classification_aliases
      DataCycleCore::ClassificationAlias.includes(classifications: :user_groups).where(classifications: { user_groups: pluck(:id) })
    end

    def self.shared_collections
      DataCycleCore::Collection.includes(:collection_shares).where(collection_shares: { shareable_id: pluck(:id) })
    end

    def self.search_columns
      columns.select { |c| c.type == :string }.map(&:name)
    end

    def self.users
      DataCycleCore::User.where(id: joins('INNER JOIN user_group_users user_group_users_user_groups ON user_group_users_user_groups.user_group_id = user_groups.id').pluck('user_group_users_user_groups.user_id'))
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id:,
        name: ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon user_group-icon'),
          name
        ].compact, ' '),
        html_class: model_name.param_key,
        dc_tooltip: "#{model_name.human(count: 1, locale:)}: #{name}",
        class_key: model_name.param_key
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end
  end
end
