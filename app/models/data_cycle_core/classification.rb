# frozen_string_literal: true

module DataCycleCore
  class Classification < ApplicationRecord
    validates :name, presence: true

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'

    acts_as_paranoid

    has_many :classification_contents, dependent: :delete_all
    has_many :things, through: :classification_contents, source: 'content_data'
    has_many :classification_content_histories, class_name: 'DataCycleCore::ClassificationContent::History'
    has_many :thing_histories, through: :classification_content_histories, source: 'content_data_history'

    has_many :classification_groups, dependent: :destroy
    has_many :classification_aliases, through: :classification_groups
    has_one :primary_classification_group, class_name: 'DataCycleCore::ClassificationGroup::PrimaryClassificationGroup'
    has_one :primary_classification_alias, through: :primary_classification_group, source: :classification_alias

    has_many :additional_classification_groups, lambda {
      where.not('EXISTS (SELECT 1 FROM primary_classification_groups WHERE primary_classification_groups.id = classification_groups.id)')
    }, class_name: 'DataCycleCore::ClassificationGroup'
    has_many :additional_classification_aliases, through: :additional_classification_groups, source: :classification_alias

    has_many :classification_user_groups, dependent: :destroy
    has_many :user_groups, through: :classification_user_groups

    has_one :concept

    def self.for_tree(tree_name)
      joins(primary_classification_alias: { classification_tree: :classification_tree_label })
        .where(classification_aliases: { classification_trees: { classification_tree_labels: { name: tree_name } } })
    end

    def self.by_external_key(external_source_id, external_keys)
      return none if external_source_id.blank? || external_keys.blank?

      where(external_source_id:, external_key: external_keys)
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_source&.identifier })
        .merge(attributes)
    end

    def mapped_to
      classification_aliases.where.not(id: primary_classification_alias.id)
    end

    def self.things
      return DataCycleCore::Thing.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::Thing.includes(:classifications).where(classifications: { id: select(:id) })
    end

    def self.classification_aliases
      return DataCycleCore::ClassificationAlias.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::ClassificationAlias.includes(:classifications).where(classifications: { id: select(:id) })
    end

    def self.primary_classification_aliases
      return DataCycleCore::ClassificationAlias.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::ClassificationAlias.includes(:primary_classification).where(classifications: { id: select(:id) })
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 5.days + Random.rand(2.5.days), race_condition_ttl: 60.seconds) do
        [primary_classification_alias] + primary_classification_alias.ancestors
      end
    end

    def descendants
      Rails.cache.fetch("#{cache_key}/descendants", expires_in: 5.days + Random.rand(2.5.days), race_condition_ttl: 60.seconds) do
        primary_classification_alias.try(:descendants).try(:to_a).try(:flatten)
          .try(:map, &:classifications).try(&:to_a).try(&:flatten) || []
      end
    end
  end
end
