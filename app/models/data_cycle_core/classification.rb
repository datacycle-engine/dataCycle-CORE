# frozen_string_literal: true

module DataCycleCore
  class Classification < ApplicationRecord
    belongs_to :external_source

    acts_as_paranoid

    has_many :classification_contents, dependent: :destroy
    has_many :things, through: :classification_contents, source: 'content_data', source_type: 'DataCycleCore::Thing'
    has_many :classification_content_histories, class_name: 'DataCycleCore::ClassificationContent::History'
    has_many :thing_histories, through: :classification_content_histories, source: 'content_data_history', source_type: 'DataCycleCore::Thing::History'

    has_many :classification_groups, dependent: :destroy
    has_many :classification_aliases, through: :classification_groups
    has_one :primary_classification_group, class_name: 'DataCycleCore::ClassificationGroup::PrimaryClassificationGroup'
    has_one :primary_classification_alias, through: :primary_classification_group, source: :classification_alias

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 5.days + Random.rand(2.5.days)) do
        [primary_classification_alias] + primary_classification_alias.ancestors
      end
    end

    def descendants
      Rails.cache.fetch("#{cache_key}/descendants", expires_in: 5.days + Random.rand(2.5.days)) do
        primary_classification_alias.try(:descendants).try(:to_a).try(:flatten)
          .try(:map, &:classifications).try(&:to_a).try(&:flatten) || []
      end
    end
  end
end
