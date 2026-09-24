# frozen_string_literal: true

module DataCycleCore
  class UserGroup < ApplicationRecord
    validates :name, presence: true

    has_many :user_group_users, dependent: :destroy
    has_many :users, through: :user_group_users
    attribute :permissions, :jsonb, default: -> { [] }

    has_many :collection_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :shared_collections, through: :collection_shares, source: :collection

    has_many :concept_user_groups, dependent: :destroy
    has_many :concepts, through: :concept_user_groups
    has_many :display_concepts, -> { where(concepts: { internal: false }) }, through: :concept_user_groups, source: :concept

    scope :fulltext_search, lambda { |search_term|
                              where(search_term.to_s.split.map { |term| sanitize_sql_for_conditions(["concat_ws(' ', #{search_columns.join(', ')}) ILIKE ?", "%#{term.strip}%"]) }.join(' AND '))
                            }

    scope :user_groups_with_permission, ->(key) { key.blank? ? none : where('permissions ? :key', key:) }

    DataCycleCore::Feature::UserGroupClassification.attribute_relations.each do |key, config|
      has_many key.to_sym, -> { for_tree(config['tree_label']) }, through: :concept_user_groups, source: :concept

      define_singleton_method key.to_sym do
        concepts.includes(:concept_scheme).where(concept_schemes: { name: config['tree_label'] })
      end
    end

    def self.concepts
      DataCycleCore::Concept.includes(:user_groups).where(user_groups: { id: pluck(:id) })
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
