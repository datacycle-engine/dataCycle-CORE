module DataCycleCore
  class Classification < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    acts_as_paranoid

    has_many :classification_places, dependent: :destroy
    has_many :places, through: :classification_places

    has_many :classification_creative_works, dependent: :destroy
    has_many :creative_works, through: :classification_creative_works

    has_many :classification_groups, dependent: :destroy
    has_many :classification_aliases, through: :classification_groups

    has_one :primary_classification_group, -> { max_by(&:created_at) }, class_name: ClassificationGroup

    def primary_classification_group
      classification_groups.max_by(&:created_at)
    end

    def primary_classification_alias
      primary_classification_group.classification_alias
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes) do
        [primary_classification_alias] + primary_classification_alias.ancestors
      end
    end
  end
end
