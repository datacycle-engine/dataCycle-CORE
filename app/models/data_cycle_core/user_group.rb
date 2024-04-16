# frozen_string_literal: true

module DataCycleCore
  class UserGroup < ApplicationRecord
    validates :name, presence: true

    has_many :user_group_users, dependent: :destroy
    has_many :users, through: :user_group_users

    has_many :collection_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :shared_collections, through: :collection_shares

    has_many :classification_user_groups, dependent: :destroy
    has_many :classifications, through: :classification_user_groups
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where(classification_aliases: { internal: false }) }, through: :classification_groups, source: :classification_alias

    scope :fulltext_search, lambda { |search_term|
                              where(search_term.to_s.split.map { |term| sanitize_sql_for_conditions(["concat_ws(' ', #{search_columns.join(', ')}) ILIKE ?", "%#{term.strip}%"]) }.join(' AND '))
                            }

    DataCycleCore::Feature::UserGroupClassification.attribute_relations.each do |key, config|
      has_many key.to_sym, -> { for_tree(config['tree_label']) }, through: :classification_groups, source: :classification_alias

      define_singleton_method key.to_sym do
        classification_aliases.includes(:classification_tree_label).where(classification_tree_labels: { name: config['tree_label'] })
      end
    end

    def self.classification_aliases
      return DataCycleCore::ClassificationAlias.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::ClassificationAlias.includes(classifications: :user_groups).where(classifications: { user_groups: select(:id) })
    end

    def self.search_columns
      columns.select { |c| c.type == :string }.map(&:name)
    end

    def self.users
      return DataCycleCore::User.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::User.where(id: joins('INNER JOIN user_group_users user_group_users_user_groups ON user_group_users_user_groups.user_group_id = user_groups.id').select('user_group_users_user_groups.user_id'))
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id,
        ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon user_group-icon'),
          name
        ].compact, ' '),
        model_name.param_key,
        "#{model_name.human(count: 1, locale:)}: #{name}"
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end
  end
end
