# frozen_string_literal: true

module DataCycleCore
  class UserGroup < ApplicationRecord
    validates :name, presence: true

    has_many :user_group_users, dependent: :destroy
    has_many :users, through: :user_group_users

    has_many :watch_list_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :watch_lists, through: :watch_list_shares

    has_many :classification_user_groups, dependent: :destroy
    has_many :classifications, through: :classification_user_groups
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where(classification_aliases: { internal: false }) }, through: :classification_groups, source: :classification_alias

    DataCycleCore::Feature::UserGroupClassification.attribute_relations.each do |key, config|
      define_method key.to_sym do
        classification_aliases.includes(:classification_tree_label).where(classification_tree_labels: { name: config['tree_label'] })
      end

      define_singleton_method key.to_sym do
        classification_aliases.includes(:classification_tree_label).where(classification_tree_labels: { name: config['tree_label'] })
      end
    end

    def self.classification_aliases
      DataCycleCore::ClassificationAlias.includes(classifications: :user_groups).where(classifications: { user_groups: all })
    end
  end
end
