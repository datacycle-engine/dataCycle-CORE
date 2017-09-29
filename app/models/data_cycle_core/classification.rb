module DataCycleCore
  class Classification < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    acts_as_paranoid

    DataCycleCore.content_tables.each do |content_table|
      has_many "classification_#{content_table}".to_sym, dependent: :destroy
      has_many content_table.to_sym, through: "classification_#{content_table}".to_sym

      has_many "classification_#{content_table.singularize}_histories".to_sym
      has_many "#{content_table.singularize}_histories".to_sym, through: "classification_#{content_table.singularize}_histories".to_sym
    end

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
